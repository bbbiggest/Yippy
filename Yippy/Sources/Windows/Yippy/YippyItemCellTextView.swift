//
//  YippyItemCellTextView.swift
//  Yippy
//
//  Created by Matthew Davidson on 11/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyItemCellTextView: NSTextView {

    override func menu(for event: NSEvent) -> NSMenu? {
        var ancestor = superview
        while let view = ancestor {
            if let table = view as? YippyTableView {
                return table.menu(for: event)
            }
            ancestor = view.superview
        }
        return super.menu(for: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        self.nextResponder?.mouseDown(with: event)
    }
    
    var textInset: NSEdgeInsets = NSEdgeInsetsZero {
        didSet {
            textContainerInset = CGSize(width: (textInset.left + textInset.right)/2, height: (textInset.top + textInset.bottom)/2)
        }
    }
    
    var usingEdgeInsets = false
    
    override var textContainerOrigin: NSPoint {
        if usingEdgeInsets {
            return NSPoint(x: textInset.left, y: textInset.top)
        }
        else {
            return super.textContainerOrigin
        }
    }
}
