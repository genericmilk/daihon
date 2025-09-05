import AppKit
import SwiftUI

@main
struct DaihonAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { PreferencesWindowController.shared.show() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a status bar app (no Dock) and elevate to Dock when needed (e.g., Preferences)
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "tray.full", accessibilityDescription: "Daihon")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuContentView())

        // Try to set a custom application icon for Dock and Cmd-Tab
        setApplicationIconIfAvailable()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

// MARK: - Dock menu & Icon
extension AppDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool
    {
        if !flag {
            PreferencesWindowController.shared.show()
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Daihon", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func setApplicationIconIfAvailable() {
        // Preferred: AppIcon.png in bundle resources or Daihon.icns
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "AppIcon", withExtension: "png"),
            bundle.url(forResource: "Daihon", withExtension: "icns"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let img = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = img
                return
            }
        }

        // Fallback: try to find an icon next to the executable (e.g., development layout)
        let fm = FileManager.default
        let searchRoots: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath),
            URL(fileURLWithPath: fm.currentDirectoryPath).deletingLastPathComponent(),
        ]
        for root in searchRoots {
            // Look for Daihon.icon folder or a generic AppIcon.png
            let iconFolder = root.appendingPathComponent("Daihon.icon")
            let pngPath = root.appendingPathComponent("AppIcon.png")
            if let img = NSImage(contentsOf: pngPath) {
                NSApp.applicationIconImage = img
                return
            }
            if fm.fileExists(atPath: iconFolder.path) {
                // Try some common file names inside the custom icon folder
                let candidates = [
                    iconFolder.appendingPathComponent("AppIcon.png"),
                    iconFolder.appendingPathComponent("icon.png"),
                ]
                for url in candidates where fm.fileExists(atPath: url.path) {
                    if let img = NSImage(contentsOf: url) {
                        NSApp.applicationIconImage = img
                        return
                    }
                }
            }
        }
    }
}
