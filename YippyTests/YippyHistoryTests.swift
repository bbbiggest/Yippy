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
