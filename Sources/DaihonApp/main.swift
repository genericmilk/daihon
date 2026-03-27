import AppKit
import Combine
import SwiftUI
import UserNotifications

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

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    private var cancellables: Set<AnyCancellable> = []
    private var notificationsAuthorized: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a status bar app (no Dock) and elevate to Dock when needed (e.g., Preferences)
        NSApp.setActivationPolicy(.accessory)

        // Configure UserNotifications (only if running from proper app bundle)
        configureNotificationsIfAvailable()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            setupMenuBarIcon(for: button)
        }
        refreshMenu()

        // Rebuild menu when projects list or running processes change
        AppState.shared.$sidebarItems
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

    private func configureNotificationsIfAvailable() {
        // Check if we're running from a proper app bundle
        let bundlePath = Bundle.main.bundleURL.path
        let bundleExtension = Bundle.main.bundleURL.pathExtension
        let bundleIdentifier = Bundle.main.bundleIdentifier
        print("Bundle path: \(bundlePath)")
        print("Bundle extension: \(bundleExtension)")
        print("Bundle identifier: \(bundleIdentifier ?? "unknown")")
        
        // Only try UserNotifications if we have a proper bundle with identifier
        if bundleIdentifier != nil && bundleExtension == "app" {
            print("Running from app bundle, configuring UserNotifications")
            configureUserNotifications()
        } else {
            print("Running from development build, using fallback notification system")
            notificationsAuthorized = true // Enable fallback notifications
        }
    }
    
    private func configureUserNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // First check current settings
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                print("Current notification authorization status: \(settings.authorizationStatus.rawValue)")
                print("Alert setting: \(settings.alertSetting.rawValue)")
                print("Sound setting: \(settings.soundSetting.rawValue)")
                print("Badge setting: \(settings.badgeSetting.rawValue)")
                
                let isAuthorized = (settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional)
                self?.notificationsAuthorized = isAuthorized
                
                if settings.authorizationStatus == .notDetermined {
                    print("Requesting notification authorization...")
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if let error = error { 
                            print("Notification auth error: \(error.localizedDescription)")
                        } else {
                            print("Authorization request completed. Granted: \(granted)")
                        }
                        DispatchQueue.main.async {
                            self?.notificationsAuthorized = granted
                            
                            // If granted, send a test notification to confirm it works
                            if granted {
                                self?.sendTestNotification()
                            }
                        }
                    }
                } else if isAuthorized {
                    print("Already authorized, sending test notification")
                    self?.sendTestNotification()
                } else {
                    print("Authorization denied. User may need to enable in System Preferences.")
                }
            }
        }
    }
    
    private func sendTestNotification() {
        let center = UNUserNotificationCenter.current()
        let testContent = UNMutableNotificationContent()
        testContent.title = "Daihon"
        testContent.body = "Notifications are now enabled for script alerts"
        testContent.sound = .default
        
        let testRequest = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)", 
            content: testContent, 
            trigger: nil
        )
        center.add(testRequest) { error in
            if let error = error {
                print("Test notification failed: \(error.localizedDescription)")
            } else {
                print("Test notification sent successfully")
            }
        }
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
        
        // Always log to console for debugging
        print("📢 \(title): \(subtitle) - \(body)")

        // Method 1: UserNotifications framework (only if available and authorized)
        if notificationsAuthorized && Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { 
                    print("Failed to schedule notification: \(error)")
                } else {
                    print("UserNotification sent successfully")
                }
            }
        } else {
            print("UserNotifications not available, using fallback methods")
        }

        // Method 2: Play system beep as audio feedback
        NSSound.beep()

        // Method 3: Show a temporary banner in the menu (update menu bar button)
        if let button = statusItem.button {
            let originalTitle = button.title
            button.title = "●"  // Show dot indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                button.title = originalTitle
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show notifications while app is active
        completionHandler([.banner, .list, .sound])
    }
    
    // Public method for ProcessManager to call
    func showProcessNotification(title: String, subtitle: String, body: String) {
        showNotification(title: title, subtitle: subtitle, body: body)
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let state = AppState.shared
        
        // Create Apps submenu
        let appsMenuItem = NSMenuItem(title: "Apps", action: nil, keyEquivalent: "")
        let appsMenu = NSMenu()
        
        if state.allProjects.isEmpty {
            let item = NSMenuItem(title: "No projects configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            appsMenu.addItem(item)
        } else {
            // Sort projects alphabetically by name
            let sortedProjects = state.allProjects.sorted { $0.name < $1.name }
            
            for project in sortedProjects {
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

                        appsMenu.setSubmenu(scriptSub, for: scriptItem)
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

                appsMenu.setSubmenu(projectMenu, for: projectItem)
                appsMenu.addItem(projectItem)
            }
        }
        
        menu.setSubmenu(appsMenu, for: appsMenuItem)
        menu.addItem(appsMenuItem)
        menu.addItem(.separator())
        
        // Check if any scripts are running to show "Stop all apps"
        let hasAnyRunningScripts = state.allProjects.contains { project in
            project.scripts.contains { script in
                ProcessManager.shared.logsPublisher(for: script.id) != nil
            }
        }
        
        if hasAnyRunningScripts {
            let stopAllItem = NSMenuItem(
                title: "Stop all apps", action: #selector(stopAllApps), keyEquivalent: "")
            menu.addItem(stopAllItem)
            menu.addItem(.separator())
        }
        
        // Footer
        let manageItem = NSMenuItem(
            title: "Manage Apps", action: #selector(openApps), keyEquivalent: "s")
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
        } else {
            ProcessManager.shared.start(script: script, in: project)

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
    
    @objc private func stopAllApps() {
        let state = AppState.shared
        var stoppedCount = 0
        
        for project in state.allProjects {
            for script in project.scripts {
                if ProcessManager.shared.logsPublisher(for: script.id) != nil {
                    ProcessManager.shared.stop(scriptID: script.id)
                    stoppedCount += 1
                }
            }
        }
        
        if stoppedCount > 0 {
            showNotification(
                title: "Apps Stopped",
                subtitle: "\(stoppedCount) app\(stoppedCount == 1 ? "" : "s") stopped",
                body: "All running apps have been stopped"
            )
        }
        
        refreshMenu()
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
        menu.addItem(withTitle: "Manage Apps", action: #selector(openApps), keyEquivalent: "s")
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
