//
//  YippyViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey
import RxSwift
import RxRelay
import RxCocoa

struct Results {
    let items: [HistoryItem]
    let isSearchResult: Bool
}

class YippyViewController: NSViewController {
    
    @IBOutlet var yippyHistoryView: YippyTableView!
    
    @IBOutlet var itemGroupScrollView: HorizontalButtonsView!
    @IBOutlet var itemCountLabel: NSTextField!
    
    @IBOutlet var searchBar: NSTextField!
    
    var yippyHistory = YippyHistory(history: State.main.history, items: [])
    
    var searchEngine = SearchEngine(data: [])
    var searchItems = [HistoryItem]()
    
    let disposeBag = DisposeBag()
    
    var isPreviewShowing = false
    
    var itemGroups = BehaviorRelay<[String]>(value: ["Clipboard", "Favourites", "Clipboard", "Favourites", "Clipboard", "Favourites"])
    
    var isRichText = Settings.main.showsRichText
    
    let results = BehaviorRelay(value: Results(items: [], isSearchResult: false))
    let selected = BehaviorRelay<Int?>(value: nil)
    private var plainTextPasteMonitor: Any?

    deinit {
        if let monitor = plainTextPasteMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.yippyDelegate = self
        
        State.main.history.subscribe(onNext: onHistoryChange)
        
        State.main.showsRichText.distinctUntilChanged().subscribe(onNext: onShowsRichText).disposed(by: disposeBag)
        
        itemGroupScrollView.bind(toData: itemGroups.asObservable()).disposed(by: disposeBag)
        itemGroupScrollView.bind(toSelected: BehaviorRelay<Int>(value: 0).asObservable()).disposed(by: disposeBag)
        // TODO: Remove this when implemented
        itemGroupScrollView.constraint(withIdentifier: "height")?.constant = 0
        
        Observable.combineLatest(
            results,
            selected.distinctUntilChanged().withPrevious(startWith: nil)
        )
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: onAllChange)
            .disposed(by: disposeBag)
        
        searchBar.delegate = self

        plainTextPasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, State.main.isHistoryPanelShown.value,
                self.view.window?.isKeyWindow == true,
                event.keyCode == 36,
                event.modifierFlags.intersection([.command, .shift, .control, .option]) == [.shift],
                (self.searchBar.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return event }
            if let selected = self.yippyHistoryView.selected {
                self.paste(selected: selected, asPlainText: true)
            }
            return nil
        }
        
        // TODO: Fix hack to make onAllChange run initially
        selected.accept(1)
        resetSelected()
        
        YippyHotKeys.downArrow.onDown(goToNextItem)
        YippyHotKeys.downArrow.onLong(goToNextItem)
        YippyHotKeys.pageDown.onDown(goToNextItem)
        YippyHotKeys.pageDown.onLong(goToNextItem)
        YippyHotKeys.upArrow.onDown(goToPreviousItem)
        YippyHotKeys.upArrow.onLong(goToPreviousItem)
        YippyHotKeys.pageUp.onDown(goToPreviousItem)
        YippyHotKeys.pageUp.onLong(goToPreviousItem)
        YippyHotKeys.escape.onDown(close)
        YippyHotKeys.return.onDown(pasteSelected)
        YippyHotKeys.ctrlAltCmdLeftArrow.onDown { State.main.panelPosition.accept(.left) }
        YippyHotKeys.ctrlAltCmdRightArrow.onDown { State.main.panelPosition.accept(.right) }
        YippyHotKeys.ctrlAltCmdDownArrow.onDown { State.main.panelPosition.accept(.bottom) }
        YippyHotKeys.ctrlAltCmdUpArrow.onDown { State.main.panelPosition.accept(.top) }
        YippyHotKeys.ctrlDelete.onDown(deleteSelected)
        YippyHotKeys.ctrlSpace.onDown(togglePreview)
        YippyHotKeys.cmdBackslash.onDown(focusSearchBar)
        
        // Paste hot keys
        YippyHotKeys.cmd0.onDown { self.shortcutPressed(key: 0) }
        YippyHotKeys.cmd1.onDown { self.shortcutPressed(key: 1) }
        YippyHotKeys.cmd2.onDown { self.shortcutPressed(key: 2) }
        YippyHotKeys.cmd3.onDown { self.shortcutPressed(key: 3) }
        YippyHotKeys.cmd4.onDown { self.shortcutPressed(key: 4) }
        YippyHotKeys.cmd5.onDown { self.shortcutPressed(key: 5) }
        YippyHotKeys.cmd6.onDown { self.shortcutPressed(key: 6) }
        YippyHotKeys.cmd7.onDown { self.shortcutPressed(key: 7) }
        YippyHotKeys.cmd8.onDown { self.shortcutPressed(key: 8) }
        YippyHotKeys.cmd9.onDown { self.shortcutPressed(key: 9) }
        
        bindHotKeyToYippyWindow(YippyHotKeys.downArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.upArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.return, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.escape, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.pageDown, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.pageUp, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlAltCmdLeftArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlAltCmdRightArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlAltCmdDownArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlAltCmdUpArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd0, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd1, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd2, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd3, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd4, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd5, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd6, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd7, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd8, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd9, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlDelete, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.ctrlSpace, disposeBag: disposeBag)
        
        searchBar.resignFirstResponder()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        isPreviewShowing = false
        resetSelected()
    }
    
    func resetSelected() {
        if yippyHistory.items.count > 0 {
            selected.accept(0)
        }
        else {
            selected.accept(nil)
        }
    }
    
    func onHistoryChange(_ history: [HistoryItem], change: History.Change) {
        updateSearchEngine(items: history)
        if !searchBar.stringValue.isEmpty {
            runSearch()
        }
        else {
            results.accept(Results(items: history, isSearchResult: false))
            switch change {
            case .insert(let i):
                if i == 0 {
                    incrementSelected()
                }
                break;
            default: break;
            }
        }
    }
    
    func updateSearchEngine(items: [HistoryItem]) {
        searchItems = items
        self.searchEngine = SearchEngine(data: items.map { $0.getPlainString() ?? "" })
    }
    
    func onAllChange(_ results: Results, _ selected: (Int?, Int?)) {
        if results.items != self.yippyHistory.items {
                if results.isSearchResult {
                    self.itemCountLabel.stringValue = "\(results.items.count) matches"
                }
                else {
                    self.itemCountLabel.stringValue = "\(results.items.count) items"
                }
                
                self.yippyHistory = YippyHistory(history: State.main.history, items: results.items)
                self.yippyHistoryView.reloadData(self.yippyHistory.items, isRichText: self.isRichText)
            }
        
        if let previous = selected.0 {
            self.yippyHistoryView.deselectItem(previous)
            self.yippyHistoryView.reloadItem(previous)
        }
        if let selected = selected.1 {
            let currentSelection = self.yippyHistoryView.selected
            if currentSelection == nil || currentSelection != selected {
                self.yippyHistoryView.selectItem(selected)
            }
            self.yippyHistoryView.reloadItem(selected)
            
            if self.isPreviewShowing {
                State.main.previewHistoryItem.accept(self.yippyHistory.items[selected])
            }
        }
    }
    
    func onShowsRichText(_ showsRichText: Bool) {
        isRichText = showsRichText
        yippyHistoryView.reloadData(yippyHistory.items, isRichText: isRichText)
    }
    
    func bindHotKeyToYippyWindow(_ hotKey: YippyHotKey, disposeBag: DisposeBag) {
        State.main.isHistoryPanelShown
            .distinctUntilChanged()
            .subscribe(onNext: { [] in
                hotKey.isPaused = !$0
            })
            .disposed(by: disposeBag)
    }
    
    func goToNextItem() {
        incrementSelected()
    }
    
    func goToPreviousItem() {
        decrementSelected()
    }
    
    func pasteSelected() {
        if let selected = self.yippyHistoryView.selected {
            paste(selected: selected)
        }
    }
    
    func deleteSelected() {
        if let selected = self.yippyHistoryView.selected {
            self.selected.accept(yippyHistory.delete(selected: selected))
        }
    }
    
    func close() {
        isPreviewShowing = false
        State.main.isHistoryPanelShown.accept(false)
        State.main.previewHistoryItem.accept(nil)
        resetSelected()
    }
    
    func shortcutPressed(key: Int) {
        paste(selected: key)
    }
    
    func togglePreview() {
        if let selected = yippyHistoryView.selected {
            isPreviewShowing = !isPreviewShowing
            if isPreviewShowing {
                State.main.previewHistoryItem.accept(yippyHistory.items[selected])
            }
            else {
                State.main.previewHistoryItem.accept(nil)
            }
        }
    }
    
    func focusSearchBar() {
        NSApp.activate(ignoringOtherApps: true)
        self.searchBar.becomeFirstResponder()
    }
    
    func runSearch() {
        let engine = searchEngine
        let items = searchItems
        engine.search(query: searchBar.stringValue, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.searchEngine === engine,
                    self.searchBar.stringValue == result.query.query else { return }
                if result.query.query.isEmpty {
                    self.results.accept(Results(items: items, isSearchResult: false))
                    return
                }

                let matches = result.results.compactMap { items.indices.contains($0) ? items[$0] : nil }
                self.results.accept(Results(items: matches, isSearchResult: true))
            }
        })
    }
    
    private func incrementSelected() {
        guard let s = selected.value else {
            if yippyHistory.items.count > 0 {
                selected.accept(0)
            }
            return
        }
        if s < yippyHistory.items.count - 1 {
            selected.accept(s + 1)
        }
    }
    
    private func decrementSelected() {
        guard let s = selected.value else {
            if yippyHistory.items.count > 0 {
                selected.accept(0)
            }
            return
        }
        if s > 0 {
            selected.accept(s - 1)
        }
    }
    
    private func paste(selected: Int, asPlainText: Bool = false) {
        guard yippyHistory.items.indices.contains(selected) else { return }
        if asPlainText && yippyHistory.items[selected].getPlainString() == nil {
            NSSound.beep()
            return
        }
        let destination = Controller.main.yippyWindowController.previousApplication
        let history = yippyHistory
        self.close()
        history.paste(selected: selected, asPlainText: asPlainText, to: destination)
    }
}

extension YippyViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }
}

extension YippyViewController: YippyTableViewDelegate {

    func yippyTableView(_ tableView: YippyTableView, pasteItemWithId id: UUID, asPlainText: Bool) {
        guard let index = yippyHistory.items.firstIndex(where: { $0.fsId == id }) else { return }
        paste(selected: index, asPlainText: asPlainText)
    }
    func yippyTableView(_ yippyTableView: YippyTableView, selectedDidChange selected: Int?) {
        self.selected.accept(selected)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didMoveItem from: Int, to: Int) {
        yippyHistory.move(from: from, to: to)
        selected.accept(to)
    }
}
