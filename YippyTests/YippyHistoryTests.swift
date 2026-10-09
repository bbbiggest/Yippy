import XCTest
import RxRelay
@testable import Yippy

class YippyHistoryTests: XCTestCase {
    private var cache: HistoryCache!
    private var historyFM: SelectionHistoryFileManager!
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        historyFM = SelectionHistoryFileManager(
            fileManager: FileManagerMock(),
            orderManager: ArrayFileManagerMock(url: URL(fileURLWithPath: "synthetic-history")),
            dataFileManager: DataFileManagerMock(),
            errorLogger: ErrorLoggerMock(),
            warningLogger: WarningLoggerMock(),
            alerter: AlerterMock()
        )
        cache = HistoryCache(historyFM: historyFM,
                             errorLogger: ErrorLoggerMock(), warningLogger: WarningLoggerMock())
        pasteboard = NSPasteboard.withUniqueName()
        pasteboard.setString("unchanged", forType: .string)
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        cache = nil
        historyFM = nil
        super.tearDown()
    }

    private func item(_ text: String) -> HistoryItem {
        return HistoryItem(unsavedData: [.string: Data(text.utf8)], cache: cache)
    }

    private func history(_ items: [HistoryItem]) -> History {
        return History(historyFM: historyFM, cache: cache, items: items)
    }

    private func contextMenu(for table: YippyTableView) throws -> NSMenu {
        let row = table.rect(ofRow: 0)
        let location = table.convert(NSPoint(x: row.midX, y: row.midY), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown, location: location, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        return try XCTUnwrap(table.menu(for: event))
    }

    func testFilteredPasteMovesTheSelectedEntryToTheTop() {
        let items = [item("alpha"), item("bravo"), item("charlie")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: [items[2]], pasteboard: pasteboard)

        XCTAssertTrue(displayed.preparePaste(selected: 0))

        XCTAssertEqual(history.items.map { $0.fsId }, [items[2], items[0], items[1]].map { $0.fsId })
        XCTAssertEqual(pasteboard.string(forType: .string), "charlie")
        XCTAssertEqual(history.lastRecordedChangeCount, pasteboard.changeCount)
    }

    func testDeletingTheFirstFilteredRowPreservesAnUnrelatedClipboard() {
        let items = [item("alpha"), item("bravo"), item("charlie")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: [items[2]], pasteboard: pasteboard)

        XCTAssertNil(displayed.delete(selected: 0))

        XCTAssertEqual(history.items.map { $0.fsId }, items.prefix(2).map { $0.fsId })
        XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
    }

    func testFilteredMoveResolvesSourceAndDestinationIdentities() {
        let items = [item("alpha"), item("hidden"), item("bravo"), item("charlie")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: [items[0], items[2], items[3]], pasteboard: pasteboard)

        displayed.move(from: 2, to: 1)

        XCTAssertEqual(history.items.map { $0.fsId }, [items[0], items[1], items[3], items[2]].map { $0.fsId })
    }

    func testSelectionStillRefersToTheSameEntryAfterHistoryChanges() {
        let items = [item("alpha"), item("bravo"), item("charlie")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: items, pasteboard: pasteboard)
        history.moveItem(at: 2, to: 0)

        XCTAssertTrue(displayed.preparePaste(selected: 1))

        XCTAssertEqual(history.items.first?.fsId, items[1].fsId)
        XCTAssertEqual(pasteboard.string(forType: .string), "bravo")
    }

    func testRemovedSelectionDoesNotActOnAnotherEntry() {
        let items = [item("alpha"), item("bravo"), item("charlie")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: [items[2], items[0]], pasteboard: pasteboard)
        history.deleteItem(at: 2)

        XCTAssertFalse(displayed.preparePaste(selected: 0))
        XCTAssertNil(displayed.delete(selected: 0))
        displayed.move(from: 0, to: 1)

        XCTAssertEqual(history.items.map { $0.fsId }, items.prefix(2).map { $0.fsId })
        XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
    }

    func testOutOfRangeActionsLeaveHistoryAndClipboardUnchanged() {
        let items = [item("alpha")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: items, pasteboard: pasteboard)

        XCTAssertFalse(displayed.preparePaste(selected: -1))
        XCTAssertFalse(displayed.preparePaste(selected: 1))
        XCTAssertNil(displayed.delete(selected: 1))
        displayed.move(from: 0, to: 1)

        XCTAssertEqual(history.items.map { $0.fsId }, items.map { $0.fsId })
        XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
    }

    func testSearchMatchesTheTextEntryAfterANonTextEntry() {
        let nonText = HistoryItem(unsavedData: [.tiff: Data()], cache: cache)
        let match = item("needle")
        let controller = YippyViewController(nibName: nil, bundle: nil)
        controller.searchBar = NSTextField()
        controller.searchBar.stringValue = "needle"
        controller.updateSearchEngine(items: [nonText, match])

        controller.runSearch()

        expectation(for: NSPredicate { _, _ in
            controller.results.value.items.map { $0.fsId } == [match.fsId]
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 3)
    }

    func testPlainTextPastePreservesRichDataAndTheSavedFormatChoice() {
        let previousPreference = HistoryItem.pastesRichText
        defer { HistoryItem.pastesRichText = previousPreference }
        let text = "Hello 世界 👋\nsecond\tline"
        let richData = NSAttributedString(string: text).rtf(
            from: NSRange(location: 0, length: (text as NSString).length), documentAttributes: [:])!
        let item = HistoryItem(unsavedData: [.string: Data(text.utf8), .rtf: richData], cache: cache)
        let history = self.history([item])
        let displayed = YippyHistory(history: history, items: [item], pasteboard: pasteboard)

        for richPreference in [true, false] {
            HistoryItem.pastesRichText = richPreference

            XCTAssertTrue(displayed.preparePaste(selected: 0, mode: .plainText))
            // AppKit may advertise the legacy string alias alongside the modern type.
            let textTypes: Set<NSPasteboard.PasteboardType> = [
                .string, NSPasteboard.PasteboardType("NSStringPboardType")
            ]
            let writtenTypes = Set(pasteboard.types ?? [])
            XCTAssertTrue(writtenTypes.contains(.string))
            XCTAssertTrue(writtenTypes.isSubset(of: textTypes))
            XCTAssertEqual(pasteboard.string(forType: .string), text)
            XCTAssertEqual(HistoryItem.pastesRichText, richPreference)
            XCTAssertEqual(item.data(forType: .rtf), richData)
            history.pasteboardDidChange(pasteboard, originBundleId: nil)
            XCTAssertEqual(history.items.count, 1)

            XCTAssertTrue(displayed.preparePaste(selected: 0))
            XCTAssertEqual(pasteboard.string(forType: .string), text)
            XCTAssertEqual(pasteboard.data(forType: .rtf), richPreference ? richData : nil)
        }
    }

    func testUnsupportedPlainTextPasteLeavesTheClipboardUntouched() {
        for data: [NSPasteboard.PasteboardType: Data] in [[.tiff: Data()], [.rtf: Data()]] {
            let item = HistoryItem(unsavedData: data, cache: cache)
            let history = self.history([item])
            let displayed = YippyHistory(history: history, items: [item], pasteboard: pasteboard)

            XCTAssertFalse(displayed.preparePaste(selected: 0, mode: .plainText))

            XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
            XCTAssertEqual(history.items.first?.fsId, item.fsId)
        }
    }

    func testURLPastePreservesOriginalDataPreferencesAndSubsequentPasteModes() {
        let previousPreference = HistoryItem.pastesRichText
        defer { HistoryItem.pastesRichText = previousPreference }
        let text = "https://example.com/a%20b 中?q=1+2#文"
        let richData = NSAttributedString(string: text).rtf(
            from: NSRange(location: 0, length: (text as NSString).length), documentAttributes: [:])!
        let htmlData = Data("<b>synthetic URL</b>".utf8)
        let originalData: [NSPasteboard.PasteboardType: Data] = [
            .string: Data(text.utf8), .rtf: richData, .html: htmlData,
            .URL: Data("https://example.com/alternate-representation".utf8)
        ]
        let item = HistoryItem(unsavedData: originalData, cache: cache)
        let history = self.history([item])
        let displayed = YippyHistory(history: history, items: [item], pasteboard: pasteboard)

        for richPreference in [true, false] {
            HistoryItem.pastesRichText = richPreference
            XCTAssertTrue(displayed.preparePaste(selected: 0, mode: .urlEncoded))
            XCTAssertEqual(pasteboard.string(forType: .string),
                           "https://example.com/a%20b%20%E4%B8%AD?q=1+2#%E6%96%87")
            let textTypes: Set<NSPasteboard.PasteboardType> = [
                .string, NSPasteboard.PasteboardType("NSStringPboardType")
            ]
            XCTAssertTrue(Set(pasteboard.types ?? []).isSubset(of: textTypes))
            XCTAssertEqual(HistoryItem.pastesRichText, richPreference)
            for (type, data) in originalData {
                XCTAssertEqual(item.data(forType: type), data)
            }
            history.pasteboardDidChange(pasteboard, originBundleId: nil)
            XCTAssertEqual(history.items.map { $0.fsId }, [item.fsId])

            XCTAssertTrue(displayed.preparePaste(selected: 0, mode: .plainText))
            XCTAssertEqual(pasteboard.string(forType: .string), text)
            XCTAssertTrue(displayed.preparePaste(selected: 0))
            XCTAssertEqual(pasteboard.string(forType: .string), text)
            XCTAssertEqual(pasteboard.data(forType: .rtf), richPreference ? richData : nil)
            XCTAssertEqual(pasteboard.data(forType: .html), richPreference ? htmlData : nil)
        }
    }

    func testURLPasteResolvesFilteredAndChangedHistoryByIdentity() {
        let items = [item("hidden"), item("postgresql://db.example/库 名"), item("newest")]
        let history = self.history(items)
        let displayed = YippyHistory(history: history, items: [items[1]], pasteboard: pasteboard)
        history.moveItem(at: 2, to: 0)

        XCTAssertTrue(displayed.preparePaste(selected: 0, mode: .urlEncoded))
        XCTAssertEqual(pasteboard.string(forType: .string),
                       "postgresql://db.example/%E5%BA%93%20%E5%90%8D")
        XCTAssertEqual(history.items.map { $0.fsId }, [items[1], items[2], items[0]].map { $0.fsId })
        XCTAssertEqual(history.lastRecordedChangeCount, pasteboard.changeCount)

        history.deleteItem(at: 0)
        pasteboard.clearContents()
        pasteboard.setString("unchanged", forType: .string)
        XCTAssertFalse(displayed.preparePaste(selected: 0, mode: .urlEncoded))
        XCTAssertFalse(displayed.preparePaste(selected: -1, mode: .urlEncoded))
        XCTAssertFalse(displayed.preparePaste(selected: 1, mode: .urlEncoded))
        XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
        XCTAssertEqual(history.items.map { $0.fsId }, [items[2], items[0]].map { $0.fsId })
    }

    func testUnsupportedURLPasteLeavesClipboardAndHistoryUntouched() {
        let unsupported: [[NSPasteboard.PasteboardType: Data]] = [
            [.tiff: Data()], [.rtf: Data()], [.URL: Data("https://example.com".utf8)],
            [.string: Data([0xFF])]
        ]
        for data in unsupported {
            let items = [item("first"), HistoryItem(unsavedData: data, cache: cache)]
            let history = self.history(items)
            let displayed = YippyHistory(history: history, items: [items[1]], pasteboard: pasteboard)
            let changeCount = pasteboard.changeCount

            XCTAssertFalse(displayed.preparePaste(selected: 0, mode: .urlEncoded))
            XCTAssertEqual(pasteboard.changeCount, changeCount)
            XCTAssertEqual(pasteboard.string(forType: .string), "unchanged")
            XCTAssertEqual(history.items.map { $0.fsId }, items.map { $0.fsId })
        }
    }

    func testContextMenuOffersURLPasteForTextWithoutAShortcut() throws {
        let table = YippyTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("synthetic")))
        for hasText in [true, false] {
            let item = hasText ? self.item("hello world") : HistoryItem(unsavedData: [.tiff: Data()], cache: cache)
            table.reloadData([item], isRichText: false)
            let menu = try contextMenu(for: table)
            XCTAssertEqual(menu.items.map { $0.title }, ["Paste", "Paste as Plain Text", "Paste as URL-Encoded Text"])
            XCTAssertTrue(menu.items[0].isEnabled)
            XCTAssertEqual(menu.items[0].keyEquivalent, "\r")
            XCTAssertEqual(menu.items[0].keyEquivalentModifierMask, [])
            XCTAssertEqual(menu.items[1].keyEquivalent, "\r")
            XCTAssertEqual(menu.items[1].keyEquivalentModifierMask, [.shift])
            XCTAssertEqual(menu.items[1].isEnabled, hasText)
            let action = menu.items[2]
            XCTAssertEqual(action.isEnabled, hasText)
            XCTAssertEqual(action.keyEquivalent, "")
            XCTAssertEqual(action.keyEquivalentModifierMask, [])
            XCTAssertEqual(action.representedObject as? UUID, item.fsId)
            XCTAssertEqual(action.tag, PasteMode.urlEncoded.rawValue)
            XCTAssertNotNil(action.toolTip)
        }
    }

    func testContextMenuRetainsItemIdentityAndPasteModeAfterRowsChange() throws {
        let table = YippyTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("synthetic")))
        let delegate = PasteMenuDelegate()
        table.yippyDelegate = delegate
        let original = item("original URL")
        table.reloadData([original], isRichText: false)
        let menu = try contextMenu(for: table)
        table.reloadData([item("replacement")], isRichText: false)

        for (index, mode) in [PasteMode.standard, .plainText, .urlEncoded].enumerated() {
            let dispatched = expectation(description: "Context-menu paste dispatched")
            delegate.onPaste = { dispatched.fulfill() }
            let action = menu.items[index]
            table.perform(try XCTUnwrap(action.action), with: action)
            waitForExpectations(timeout: 1)
            XCTAssertEqual(delegate.pastedId, original.fsId)
            XCTAssertEqual(delegate.mode, mode)
        }
    }

    func testCellBackgroundAndTextUseTheTableContextMenu() throws {
        let table = YippyTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("synthetic")))
        let original = item("synthetic menu item")
        table.reloadData([original], isRichText: false)
        let cell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? YippyItemBaseCellView)
        let row = table.rect(ofRow: 0)
        let point = table.convert(NSPoint(x: row.midX, y: row.midY), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))

        for view in [cell, cell.itemTextView!, cell.shortcutTextView!] as [NSView] {
            let menu = try XCTUnwrap(view.menu(for: event))
            XCTAssertEqual(menu.items.map { $0.title }, ["Paste", "Paste as Plain Text", "Paste as URL-Encoded Text"])
            XCTAssertTrue(menu.items.allSatisfy { ($0.representedObject as? UUID) == original.fsId })
        }
    }

    func testContextMenuPasteWaitsUntilMenuTrackingEnds() throws {
        let table = YippyTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("synthetic")))
        let original = item("synthetic menu item")
        table.reloadData([original], isRichText: false)
        let delegate = PasteMenuDelegate()
        table.yippyDelegate = delegate
        let menu = try contextMenu(for: table)
        let action = menu.items[2]
        table.perform(try XCTUnwrap(action.action), with: action)

        RunLoop.main.run(mode: .eventTracking, before: Date().addingTimeInterval(0.02))
        XCTAssertNil(delegate.pastedId)
        let dispatched = expectation(description: "Paste after returning to the default run loop")
        delegate.onPaste = { dispatched.fulfill() }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(delegate.pastedId, original.fsId)
        XCTAssertEqual(delegate.mode, .urlEncoded)
    }
}

private class PasteMenuDelegate: YippyTableViewDelegate {
    var pastedId: UUID?
    var mode: PasteMode?
    var onPaste: (() -> Void)?

    func yippyTableView(_ tableView: YippyTableView, pasteItemWithId id: UUID, mode: PasteMode) {
        pastedId = id
        self.mode = mode
        onPaste?()
    }

    func yippyTableView(_ tableView: YippyTableView, selectedDidChange selected: Int?) {}
    func yippyTableView(_ tableView: YippyTableView, didMoveItem from: Int, to: Int) {}
}

private class SelectionHistoryFileManager: HistoryFileManager {
    override func moveItem(newHistory: [HistoryItem], from: Int, to: Int,
                           completionHandler: ((Bool) -> Void)? = nil) {
        completionHandler?(true)
    }

    override func deleteItem(newHistory: [HistoryItem], deleted: HistoryItem,
                             completionHandler handler: ((Bool) -> Void)? = nil) {
        handler?(true)
    }
}

private enum PasteTestState {
    static var foreground: NSRunningApplication?
    static var modifiers: NSEvent.ModifierFlags = []
    static var hints: [String] = []
    static var activationEvents: [String] = []
}

private final class PasteTestApplication: NSRunningApplication, @unchecked Sendable {
    let testPid: pid_t
    var testTerminated = false

    init(pid: pid_t) {
        testPid = pid
        super.init()
    }

    override var processIdentifier: pid_t { testPid }
    override var isTerminated: Bool { testTerminated }
    override func isEqual(_ object: Any?) -> Bool { (object as? PasteTestApplication)?.testPid == testPid }
    override var hash: Int { Int(testPid) }

    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        PasteTestState.activationEvents.append("activate")
        PasteTestState.foreground = self
        return true
    }

    @available(macOS 14.0, *)
    override func activate(from application: NSRunningApplication, options: NSApplication.ActivationOptions = []) -> Bool {
        return activate(options: options)
    }
}

extension NSWorkspace {
    @objc fileprivate var pasteTestForeground: NSRunningApplication? { PasteTestState.foreground }
}

extension NSEvent {
    @objc fileprivate class var pasteTestModifiers: NSEvent.ModifierFlags { PasteTestState.modifiers }
}

extension NSAlert {
    @objc fileprivate func pasteTestRunModal() -> NSApplication.ModalResponse {
        PasteTestState.hints.append(informativeText)
        return .OK
    }
}

extension NSApplication {
    @objc fileprivate func pasteTestActivate(ignoringOtherApps: Bool) {
        PasteTestState.foreground = .current
    }

    @available(macOS 14.0, *)
    @objc fileprivate func pasteTestYield(to application: NSRunningApplication) {
        PasteTestState.activationEvents.append("yield")
    }
}

private final class PasteTestControl: AccessControlHelper {
    var granted = true
    override func isControlGranted() -> Bool { granted }
}

private final class PasteTestKeys: KeyPressHelper {
    var count = 0
    override func press(keyCode: CGKeyCode, flags: CGEventFlags) { count += 1 }
}

private final class PasteTestWindowController: YippyWindowController {
    override func showWindow(_ sender: Any?) {}
    override func close() {}
}

// Intercept system state and output so these tests need no permissions, running
// destination apps, keyboard injection, modal dialogs, or general pasteboard.
private final class PasteTestRuntime {
    let control = PasteTestControl()
    let keys = PasteTestKeys()
    private let previousControl = Helper.accessControlHelper
    private let previousKeys = Helper.keyPressHelper
    private var methods: [(Method, Method)] = []

    init() throws {
        var selectors: [(AnyClass, Selector, Selector, Bool)] = [
            (NSWorkspace.self, #selector(getter: NSWorkspace.frontmostApplication), #selector(getter: NSWorkspace.pasteTestForeground), false),
            (NSEvent.self, #selector(getter: NSEvent.modifierFlags), #selector(getter: NSEvent.pasteTestModifiers), true),
            (NSAlert.self, #selector(NSAlert.runModal), #selector(NSAlert.pasteTestRunModal), false),
            (NSApplication.self, #selector(NSApplication.activate(ignoringOtherApps:)), #selector(NSApplication.pasteTestActivate(ignoringOtherApps:)), false)
        ]
        if #available(macOS 14.0, *) {
            selectors.append((NSApplication.self, #selector(NSApplication.yieldActivation(to:)), #selector(NSApplication.pasteTestYield(to:)), false))
        }
        let resolved = try selectors.map { type, original, replacement, isClass in
            (try XCTUnwrap(isClass ? class_getClassMethod(type, original) : class_getInstanceMethod(type, original)),
             try XCTUnwrap(isClass ? class_getClassMethod(type, replacement) : class_getInstanceMethod(type, replacement)))
        }
        PasteTestState.foreground = nil
        PasteTestState.modifiers = []
        PasteTestState.hints = []
        PasteTestState.activationEvents = []
        methods = resolved
        for (a, b) in methods { method_exchangeImplementations(a, b) }
        Helper.accessControlHelper = control
        Helper.keyPressHelper = keys
    }

    deinit {
        Helper.accessControlHelper = previousControl
        Helper.keyPressHelper = previousKeys
        for (a, b) in methods.reversed() { method_exchangeImplementations(a, b) }
    }
}

extension YippyHistoryTests {
    private func waitForPasteResult(_ runtime: PasteTestRuntime) {
        let deadline = Date().addingTimeInterval(3)
        while runtime.keys.count == 0 && PasteTestState.hints.isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func testAutomaticPasteHandlesFocusHandoffAndModifierRelease() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        let values = [item("synthetic text")]
        let displayed = YippyHistory(history: history(values), items: values, pasteboard: pasteboard)
        for mode in [PasteMode.standard, .plainText, .urlEncoded] {
            runtime.keys.count = 0
            PasteTestState.foreground = .current
            PasteTestState.modifiers = [.shift]
            XCTAssertTrue(displayed.paste(selected: 0, mode: mode, to: destination))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                PasteTestState.foreground = destination
                PasteTestState.modifiers = []
            }
            waitForPasteResult(runtime)
            XCTAssertEqual(runtime.keys.count, 1)
            XCTAssertTrue(PasteTestState.hints.isEmpty)
            XCTAssertEqual(pasteboard.string(forType: .string), mode == .urlEncoded ? "synthetic%20text" : "synthetic text")
        }
    }

    func testAutomaticPasteWaitsForTemporarilyUnknownForeground() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        let values = [item("synthetic text")]
        let displayed = YippyHistory(history: history(values), items: values, pasteboard: pasteboard)
        XCTAssertTrue(displayed.paste(selected: 0, mode: .plainText, to: destination))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { PasteTestState.foreground = destination }
        waitForPasteResult(runtime)
        XCTAssertEqual(runtime.keys.count, 1)
        XCTAssertTrue(PasteTestState.hints.isEmpty)
    }

    func testAutomaticPasteStopsForInvalidDestinationPermissionOrApplicationSwitch() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        let terminated = PasteTestApplication(pid: 424243)
        terminated.testTerminated = true
        let other = PasteTestApplication(pid: 424244)
        let cases: [(NSRunningApplication?, NSRunningApplication, Bool)] = [
            (nil, destination, true), (.current, .current, true),
            (terminated, destination, true), (destination, destination, false),
            (destination, other, true)
        ]
        let values = [item("synthetic text")]
        let displayed = YippyHistory(history: history(values), items: values, pasteboard: pasteboard)
        for (target, foreground, permission) in cases {
            PasteTestState.hints = []
            PasteTestState.foreground = foreground
            runtime.control.granted = permission
            XCTAssertTrue(displayed.paste(selected: 0, mode: .urlEncoded, to: target))
            waitForPasteResult(runtime)
            XCTAssertEqual(runtime.keys.count, 0)
            XCTAssertEqual(PasteTestState.hints.count, 1)
            XCTAssertEqual(pasteboard.string(forType: .string), "synthetic%20text")
            XCTAssertTrue(PasteTestState.activationEvents.isEmpty)
        }
        XCTAssertTrue(PasteTestState.hints[0].contains("active application changed"))
    }

    func testAutomaticPasteTimesOutWhileModifiersRemainHeld() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        PasteTestState.foreground = destination
        PasteTestState.modifiers = [.control]
        let values = [item("synthetic text")]
        let displayed = YippyHistory(history: history(values), items: values, pasteboard: pasteboard)
        XCTAssertTrue(displayed.paste(selected: 0, mode: .plainText, to: destination))
        waitForPasteResult(runtime)
        XCTAssertEqual(runtime.keys.count, 0)
        XCTAssertEqual(PasteTestState.hints.count, 1)
        XCTAssertTrue(PasteTestState.hints[0].contains("did not become ready"))
        XCTAssertEqual(pasteboard.string(forType: .string), "synthetic text")
    }

    func testPanelKeepsExternalDestinationAndRestoresItOnlyWhileYippyIsFrontmost() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        let other = PasteTestApplication(pid: 424243)
        let controller = PasteTestWindowController(window: nil)
        let toggle = BehaviorRelay<Bool>(value: false)
        let subscription = controller.subscribeTo(toggle: toggle)
        defer { subscription.dispose(); withExtendedLifetime(runtime) {} }

        PasteTestState.foreground = destination
        toggle.accept(true)
        XCTAssertEqual(controller.previousApplication, destination)
        toggle.accept(false)
        XCTAssertEqual(PasteTestState.foreground, destination)
        if #available(macOS 14.0, *) {
            XCTAssertEqual(PasteTestState.activationEvents, ["yield", "activate"])
        } else {
            XCTAssertEqual(PasteTestState.activationEvents, ["activate"])
        }

        PasteTestState.foreground = .current
        toggle.accept(true)
        XCTAssertEqual(controller.previousApplication, destination)
        PasteTestState.activationEvents = []
        PasteTestState.foreground = other
        toggle.accept(false)
        XCTAssertTrue(PasteTestState.activationEvents.isEmpty)
        XCTAssertEqual(PasteTestState.foreground, other)
    }

    func testPanelDiscardsStaleDestinationWhenForegroundCannotBeIdentified() throws {
        let runtime = try PasteTestRuntime()
        let destination = PasteTestApplication(pid: 424242)
        let controller = PasteTestWindowController(window: nil)
        let toggle = BehaviorRelay<Bool>(value: false)
        let subscription = controller.subscribeTo(toggle: toggle)
        defer { subscription.dispose(); withExtendedLifetime(runtime) {} }

        PasteTestState.foreground = destination
        toggle.accept(true)
        toggle.accept(false)
        XCTAssertEqual(controller.previousApplication, destination)

        PasteTestState.foreground = nil
        PasteTestState.activationEvents = []
        toggle.accept(true)
        XCTAssertNil(controller.previousApplication)
        toggle.accept(false)
        XCTAssertTrue(PasteTestState.activationEvents.isEmpty)
    }
}
