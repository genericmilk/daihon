import AppKit
import SwiftUI

final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: PreferencesView())
        let win = NSWindow(contentViewController: hosting)
        // Style: no visible title bar, inset traffic lights, not full-screenable
        win.title = "Preferences"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isOpaque = true
        win.backgroundColor = NSColor.windowBackgroundColor
        win.styleMask = [.titled, .closable, .resizable]
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("PreferencesToolbar"))
        toolbar.showsBaselineSeparator = false
        win.toolbar = toolbar
        if #available(macOS 11.0, *) {
            win.toolbarStyle = .unifiedCompact
        }
        win.isMovableByWindowBackground = true
        // Disable full screen behavior and zoom-to-fullscreen
        win.collectionBehavior.remove([
            .fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling,
        ])
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.setContentSize(NSSize(width: 720, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        // Show app in Dock while Preferences is visible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Release the window so a fresh one is created next time.
        window = nil
        // Return to status-bar-only: hide Dock icon when Preferences closes
        NSApp.setActivationPolicy(.accessory)
    }
}
