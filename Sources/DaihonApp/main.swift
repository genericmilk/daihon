import AppKit
import Combine
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

class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a status bar app (no Dock) and elevate to Dock when needed (e.g., Preferences)
        NSApp.setActivationPolicy(.accessory)

        // Configure notification center delegate
        NSUserNotificationCenter.default.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            setupMenuBarIcon(for: button)
        }
        refreshMenu()

        // Rebuild menu when projects list or running processes change
        AppState.shared.$projects
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMenu() }
            .store(in: &cancellables)
        ProcessManager.shared.$running
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMenu() }
            .store(in: &cancellables)

        // Try to set a custom application icon for Dock and Cmd-Tab
        setApplicationIconIfAvailable()
    }

    private func setupMenuBarIcon(for button: NSStatusBarButton) {
        // First try to load from app bundle Resources
        if let bundleIconURL = Bundle.main.url(forResource: "foreground", withExtension: "png"),
            let bundleImage = NSImage(contentsOf: bundleIconURL)
        {
            print("Loaded custom icon from app bundle: \(bundleIconURL.path)")
            let resizedImage = resizeImageForMenuBar(bundleImage)
            button.image = resizedImage
            button.toolTip = "Daihon"

            // Force refresh the status item
            DispatchQueue.main.async {
                button.needsDisplay = true
            }
            return
        }

        // Try to load the custom foreground.png from icon-res directory (for development)
        let fm = FileManager.default
        let searchRoots: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath),
            URL(fileURLWithPath: fm.currentDirectoryPath).deletingLastPathComponent(),
        ]

        for root in searchRoots {
            let iconPath = root.appendingPathComponent("icon-res/foreground.png")
            if fm.fileExists(atPath: iconPath.path), let image = NSImage(contentsOf: iconPath) {
                print("Successfully loaded custom icon from: \(iconPath.path)")
                let resizedImage = resizeImageForMenuBar(image)
                button.image = resizedImage
                button.toolTip = "Daihon"

                // Force refresh the status item
                DispatchQueue.main.async {
                    button.needsDisplay = true
                }
                return
            }
        }

        print("Custom icon not found, using fallback system icon")
        // Fallback to system icon if custom icon not found
        button.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Daihon")
    }

    private func resizeImageForMenuBar(_ image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let resizedImage = NSImage(size: targetSize)

        resizedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0)
        resizedImage.unlockFocus()

        // Set as template to enable automatic appearance inversion
        resizedImage.isTemplate = true

        print("Created resized image: \(targetSize) - template: true")
        return resizedImage
    }

    private func showNotification(title: String, subtitle: String, body: String) {
        guard AppState.shared.preferences.showNotifications else {
            // Still log for debugging when notifications disabled
            print("(notifications off) \(title): \(subtitle) - \(body)")
            return
        }
        // Method 1: Try NSUserNotification (may not work due to permissions)
        let notification = NSUserNotification()
        notification.title = title
        notification.subtitle = subtitle
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)

        // Method 2: Always log to console for debugging
        print("📢 \(title): \(subtitle) - \(body)")

        // Method 3: Play system beep as audio feedback
        NSSound.beep()

        // Method 4: Show a temporary banner in the menu (update menu bar button)
        if let button = statusItem.button {
            let originalTitle = button.title
            button.title = "●"  // Show dot indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                button.title = originalTitle
            }
        }
    }

    // MARK: - NSUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification
    ) -> Bool {
        // Always show notifications, even when app is active
        return true
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let state = AppState.shared
        if state.projects.isEmpty {
            let item = NSMenuItem(title: "No projects configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        } else {
            for project in state.projects {
                let projectMenu = NSMenu()
                if project.scripts.isEmpty {
                    let empty = NSMenuItem(title: "No scripts", action: nil, keyEquivalent: "")
                    empty.isEnabled = false
                    projectMenu.addItem(empty)
                } else {
                    for script in project.scripts {
                        let scriptSub = NSMenu()
                        let isRunning = ProcessManager.shared.logsPublisher(for: script.id) != nil
                        let primaryTitle = isRunning ? "Stop" : "Start"
                        let startStopItem = NSMenuItem(
                            title: primaryTitle, action: #selector(toggleScript(_:)),
                            keyEquivalent: "")
                        startStopItem.representedObject = ScriptMenuContext(
                            projectID: project.id, scriptID: script.id)
                        scriptSub.addItem(startStopItem)

                        // Add restart option (only if script is running)
                        if isRunning {
                            let restartItem = NSMenuItem(
                                title: "Restart", action: #selector(restartScript(_:)),
                                keyEquivalent: "")
                            restartItem.representedObject = ScriptMenuContext(
                                projectID: project.id, scriptID: script.id)
                            scriptSub.addItem(restartItem)
                        }

                        let logsItem = NSMenuItem(
                            title: "Logs", action: #selector(openLogs(_:)), keyEquivalent: "")
                        logsItem.representedObject = ScriptMenuContext(
                            projectID: project.id, scriptID: script.id)
                        scriptSub.addItem(logsItem)

                        let scriptItem = NSMenuItem(
                            title: script.name, action: nil, keyEquivalent: "")

                        // Add running indicator icon to script item
                        if isRunning {
                            scriptItem.image = NSImage(
                                systemSymbolName: "play.fill", accessibilityDescription: "Running")
                        }

                        menu.setSubmenu(scriptSub, for: scriptItem)
                        projectMenu.addItem(scriptItem)
                    }
                }
                let projectItem = NSMenuItem(title: project.name, action: nil, keyEquivalent: "")

                // Add running indicator icon to project item if any scripts are running
                let hasRunningScripts = project.scripts.contains { script in
                    ProcessManager.shared.logsPublisher(for: script.id) != nil
                }
                if hasRunningScripts {
                    projectItem.image = NSImage(
                        systemSymbolName: "dot.radiowaves.left.and.right",
                        accessibilityDescription: "Has running scripts")
                }

                menu.setSubmenu(projectMenu, for: projectItem)
                menu.addItem(projectItem)
            }
            // Add separator after all projects
            menu.addItem(.separator())
        }
        // Footer
        let manageItem = NSMenuItem(
            title: "Apps…", action: #selector(openApps), keyEquivalent: "s")
        menu.addItem(manageItem)
        menu.addItem(
            withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Daihon", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func toggleScript(_ sender: NSMenuItem) {
        guard let ctx = sender.representedObject as? ScriptMenuContext,
            let project = AppState.shared.projects.first(where: { $0.id == ctx.projectID }),
            let script = project.scripts.first(where: { $0.id == ctx.scriptID })
        else { return }
        let isRunning = ProcessManager.shared.logsPublisher(for: script.id) != nil
        if isRunning {
            ProcessManager.shared.stop(scriptID: script.id)
            showNotification(
                title: "Script Stopped",
                subtitle: project.name,
                body: "'\(script.name)' has been stopped"
            )
        } else {
            ProcessManager.shared.start(script: script, in: project)
            showNotification(
                title: "Script Started",
                subtitle: project.name,
                body: "'\(script.name)' is now running"
            )

            // Automatically open the execution log when starting a script
            let logState = ScriptLogState(
                projectID: project.id, scriptID: script.id,
                title: "\(project.name) • \(script.name)")
            LogWindowController.shared.show(logState: logState)
        }
        refreshMenu()
    }

    @objc private func restartScript(_ sender: NSMenuItem) {
        guard let ctx = sender.representedObject as? ScriptMenuContext,
            let project = AppState.shared.projects.first(where: { $0.id == ctx.projectID }),
            let script = project.scripts.first(where: { $0.id == ctx.scriptID })
        else { return }

        ProcessManager.shared.restart(script: script, in: project)
        showNotification(
            title: "Script Restarted",
            subtitle: project.name,
            body: "'\(script.name)' has been restarted"
        )

        // Automatically open the execution log when restarting a script
        let logState = ScriptLogState(
            projectID: project.id, scriptID: script.id, title: "\(project.name) • \(script.name)")
        LogWindowController.shared.show(logState: logState)

        refreshMenu()
    }

    @objc private func openLogs(_ sender: NSMenuItem) {
        guard let ctx = sender.representedObject as? ScriptMenuContext,
            let project = AppState.shared.projects.first(where: { $0.id == ctx.projectID }),
            let script = project.scripts.first(where: { $0.id == ctx.scriptID })
        else { return }
        let logState = ScriptLogState(
            projectID: project.id, scriptID: script.id, title: "\(project.name) • \(script.name)")
        LogWindowController.shared.show(logState: logState)
    }
}

private struct ScriptMenuContext {
    let projectID: UUID
    let scriptID: UUID
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
        menu.addItem(withTitle: "Apps…", action: #selector(openApps), keyEquivalent: "s")
        menu.addItem(
            withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Daihon", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func openApps() {
        AppsWindowController.shared.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func setApplicationIconIfAvailable() {
        // Preferred: AppIcon.icns in bundle resources, then AppIcon.png
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "AppIcon", withExtension: "icns"),
            bundle.url(forResource: "AppIcon", withExtension: "png"),
            bundle.url(forResource: "Daihon", withExtension: "icns"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let img = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = img
                print("Set application icon from: \(url.path)")
                return
            }
        }

        // Try to load from AppIcon.icon
        if let resourceURL = bundle.resourceURL {
            let svgURL = resourceURL.appendingPathComponent(
                "AppIcon.icon/Assets/Recraft Untitled Image.svg")
            if FileManager.default.fileExists(atPath: svgURL.path),
                let img = NSImage(contentsOf: svgURL)
            {
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
            // Look for AppIcon.icon folder or a generic AppIcon.png
            let iconFolder = root.appendingPathComponent("AppIcon.icon")
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
                    iconFolder.appendingPathComponent("Assets/Recraft Untitled Image.svg"),
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
