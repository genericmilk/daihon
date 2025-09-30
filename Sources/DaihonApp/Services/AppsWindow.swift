import AppKit
import SwiftUI

final class AppsWindowController: NSObject, NSWindowDelegate {
    static let shared = AppsWindowController()

    private var window: NSWindow?

    func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: AppsView())
        let win = NSWindow(contentViewController: hosting)
        // Style: standard window with visible titlebar
        win.title = "Apps"
        win.titleVisibility = .visible
        win.titlebarAppearsTransparent = false
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.isMovableByWindowBackground = false
        win.toolbarStyle = .automatic
        // Disable full screen behavior and zoom-to-fullscreen
        win.collectionBehavior.remove([
            .fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling,
        ])
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.setContentSize(NSSize(width: 900, height: 600))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        // Show app in Dock while Apps is visible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Return to status-bar-only: hide Dock icon when Apps closes
        NSApp.setActivationPolicy(.accessory)
    }
}
