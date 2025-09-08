import AppKit
import SwiftUI

final class LogWindowController: NSObject {
    static let shared = LogWindowController()
    private var windows: [UUID: NSWindow] = [:]  // key scriptID

    func show(logState: ScriptLogState) {
        let key = logState.scriptID
        if let win = windows[key] {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: LogWindowView(logState: logState))
        let win = NSWindow(contentViewController: hosting)
        win.title = logState.title
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 700, height: 400))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        windows[key] = win
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension LogWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            windows = windows.filter { $0.value != win }
        }
    }
}
