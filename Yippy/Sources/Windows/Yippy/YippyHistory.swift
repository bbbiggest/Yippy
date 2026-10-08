//
//  YippyHistory.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyHistory {
    
    let history: History
    var items: [HistoryItem]
    
    let pasteboard: NSPasteboard
    
    init(history: History, items: [HistoryItem], pasteboard: NSPasteboard = .general) {
        self.history = history
        self.items = items
        self.pasteboard = pasteboard
    }
    
    func paste(selected: Int) {
        guard preparePaste(selected: selected) else { return }

        DispatchQueue.main.async {
            self.executePaste(startTime: Date())
        }
    }

    @discardableResult
    func preparePaste(selected: Int) -> Bool {
        guard let index = historyIndex(forDisplayedIndex: selected) else { return false }
        let item = history.items[index]

        // Internally action the pasteboard change
        // Our pasteboard monitor will detect the change
        // But our `History` will know that it has already been consumed
        pasteboard.clearContents()
        
        // Write object
        let written = pasteboard.writeObjects([item])
        history.recordPasteboardChange(withCount: pasteboard.changeCount)
        guard written else { return false }
        history.moveItem(at: index, to: 0)
        return true
    }
    
    private func executePaste(startTime: Date) {
        if NSApp.isActive {
            if Date().timeIntervalSince(startTime) > 2 {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.03) {
                self.executePaste(startTime: startTime)
            }
        }
        else {
            Helper.pressCommandV()
        }
    }
    
    /// Returns the next item to select
    func delete(selected: Int) -> Int? {
        guard let index = historyIndex(forDisplayedIndex: selected) else { return nil }
        let remainingCount = items.count - 1
        history.deleteItem(at: index)
        if index == 0 {
            // If we want to remove this, then we may have to change the `HistoryItem` writingOptions() to not `.promised`, because if something is pasted from history, then deleted, it can no longer satisfy the promise.
            pasteboard.clearContents()
        }
        
        return remainingCount > 0 ? min(selected, remainingCount - 1) : nil
    }
    
    func move(from: Int, to: Int) {
        guard from != to,
            let source = historyIndex(forDisplayedIndex: from),
            let destination = historyIndex(forDisplayedIndex: to) else { return }
        let item = history.items[source]
        history.moveItem(at: source, to: destination)
        
        if to == 0 {
            pasteboard.clearContents()
            
            // Write object
            pasteboard.writeObjects([item])
            history.recordPasteboardChange(withCount: pasteboard.changeCount)
        }
    }

    private func historyIndex(forDisplayedIndex index: Int) -> Int? {
        guard items.indices.contains(index) else { return nil }
        let id = items[index].fsId
        return history.items.firstIndex { $0.fsId == id }
    }
}
