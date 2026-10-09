//
//  YippyHistory.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

enum PasteMode: Int {
    case standard
    case plainText
    case urlEncoded
}

class YippyHistory {
    
    let history: History
    var items: [HistoryItem]
    
    let pasteboard: NSPasteboard
    
    init(history: History, items: [HistoryItem], pasteboard: NSPasteboard = .general) {
        self.history = history
        self.items = items
        self.pasteboard = pasteboard
    }
    
    @discardableResult
    func paste(selected: Int, mode: PasteMode = .standard, to destination: NSRunningApplication?) -> Bool {
        guard preparePaste(selected: selected, mode: mode) else { return false }

        DispatchQueue.main.async {
            self.executePaste(startTime: Date(), destination: destination)
        }
        return true
    }

    @discardableResult
    func preparePaste(selected: Int, mode: PasteMode = .standard) -> Bool {
        guard let index = historyIndex(forDisplayedIndex: selected) else { return false }
        let item = history.items[index]
        let writer: NSPasteboardWriting
        switch mode {
        case .standard:
            writer = item
        case .plainText, .urlEncoded:
            guard let text = item.getPlainString() else { return false }
            let output = mode == .urlEncoded ? URLEncoding.encode(text) : text
            let plainItem = NSPasteboardItem()
            guard plainItem.setString(output, forType: .string) else { return false }
            writer = plainItem
        }

        // Internally action the pasteboard change
        // Our pasteboard monitor will detect the change
        // But our `History` will know that it has already been consumed
        pasteboard.clearContents()
        
        // Write object
        let written = pasteboard.writeObjects([writer])
        history.recordPasteboardChange(withCount: pasteboard.changeCount)
        guard written else { return false }
        history.moveItem(at: index, to: 0)
        return true
    }
    
    private func executePaste(startTime: Date, destination: NSRunningApplication?) {
        guard let destination = destination, !destination.isTerminated,
            Helper.isControlGranted(), Date().timeIntervalSince(startTime) < 2 else {
                showManualPasteHint()
                return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let current = NSRunningApplication.current.processIdentifier
        guard frontmost == destination.processIdentifier || frontmost == current else {
            showManualPasteHint()
            return
        }
        let modifiers = NSEvent.modifierFlags.intersection([.command, .shift, .control, .option])
        if frontmost == current || !modifiers.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.03) {
                self.executePaste(startTime: startTime, destination: destination)
            }
        }
        else {
            Helper.pressCommandV()
        }
    }

    private func showManualPasteHint() {
        let alert = NSAlert()
        alert.messageText = "Copied; automatic paste unavailable"
        alert.informativeText = "Switch to the destination application and press Command + V to paste."
        alert.runModal()
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
