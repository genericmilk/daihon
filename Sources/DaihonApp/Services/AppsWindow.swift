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
        // Style: no visible title bar, inset traffic lights, not full-screenable
        win.title = "Apps"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("AppsToolbar"))
        toolbar.showsBaselineSeparator = false
        win.toolbar = toolbar
        if #available(macOS 11.0, *) {
            win.toolbarStyle = .unifiedCompact
        }
        win.isMovableByWindowBackground = false
        // Disable full screen behavior and zoom-to-fullscreen
        win.collectionBehavior.remove([
            .fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling,
        ])
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.setContentSize(NSSize(width: 760, height: 520))
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
