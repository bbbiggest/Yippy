import XCTest
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
            let action = menu.items[index]
            table.perform(try XCTUnwrap(action.action), with: action)
            XCTAssertEqual(delegate.pastedId, original.fsId)
            XCTAssertEqual(delegate.mode, mode)
        }
    }
}

private class PasteMenuDelegate: YippyTableViewDelegate {
    var pastedId: UUID?
    var mode: PasteMode?

    func yippyTableView(_ tableView: YippyTableView, pasteItemWithId id: UUID, mode: PasteMode) {
        pastedId = id
        self.mode = mode
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
