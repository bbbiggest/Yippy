//
//  YippyWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class YippyWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 2)
        window?.setAccessibilityIdentifier(Accessibility.identifiers.yippyWindow)
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    static func createYippyWindowController() -> YippyWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "YippyWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? YippyWindowController else {
            fatalError("Failed to load YippyWindowController of type YippyWindowController from the Main storyboard.")
        }
        
        return windowController
    }
    
    private(set) var previousApplication: NSRunningApplication?
    
    func subscribeTo(toggle: BehaviorRelay<Bool>) -> Disposable {
        return toggle
            .subscribe(onNext: {
                [] in
                if !$0 {
                    let wasFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
                        == NSRunningApplication.current.processIdentifier
                    self.close()
                    if wasFrontmost, let destination = self.previousApplication,
                        destination != NSRunningApplication.current, !destination.isTerminated {
                        if #available(macOS 14.0, *) {
                            NSApp.yieldActivation(to: destination)
                            destination.activate(from: .current, options: [])
                        } else {
                            destination.activate(options: .activateIgnoringOtherApps)
                        }
                    }
                }
                else {
                    let frontmost = NSWorkspace.shared.frontmostApplication
                    if frontmost != NSRunningApplication.current {
                        self.previousApplication = frontmost
                    }
                    self.showWindow(nil)
                    self.window?.makeKey()
                    NSApp.activate(ignoringOtherApps: true)
                }
            })
    }
    
    func subscribeFrameTo(position: Observable<PanelPosition>, screen: Observable<NSScreen>) -> Disposable {
        Observable.combineLatest(position, screen).subscribe(onNext: {
            (position, screen) in
            self.window?.setFrame(position.getFrame(forScreen: screen), display: true)
        })
    }
}
