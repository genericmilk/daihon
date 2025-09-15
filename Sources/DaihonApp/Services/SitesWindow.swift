import AppKit
import SwiftUI

final class SitesWindowController: NSObject, NSWindowDelegate {
    static let shared = SitesWindowController()

    private var window: NSWindow?

    func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SitesView())
        let win = NSWindow(contentViewController: hosting)
        // Style: no visible title bar, inset traffic lights, not full-screenable
        win.title = "Sites"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.styleMask = [.titled, .closable, .resizable]
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("SitesToolbar"))
        toolbar.showsBaselineSeparator = false
        win.toolbar = toolbar
        if #available(macOS 11.0, *) {
            win.toolbarStyle = .unifiedCompact
        }
        win.isMovableByWindowBackground = true
        // Disable full screen behavior and zoom-to-fullscreen
        win.collectionBehavior.remove([.fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling])
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.setContentSize(NSSize(width: 760, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        // Show app in Dock while Sites is visible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Return to status-bar-only: hide Dock icon when Sites closes
        NSApp.setActivationPolicy(.accessory)
    }
}
