import Foundation
import AppKit

// Import the app modules
@testable import DaihonApp

// Test the notification system
let appDelegate = AppDelegate()
let testProject = Project(
    id: UUID(),
    name: "Test Project",
    scripts: [
        Script(id: UUID(), name: "Test Script", command: "echo 'Hello World' && sleep 2")
    ]
)

// Simulate app launch
appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

// Test starting a script
let script = testProject.scripts[0]
print("Testing script start...")
ProcessManager.shared.start(script: script, in: testProject)

// Wait a bit
sleep(1)

// Test stopping the script
print("Testing script stop...")
ProcessManager.shared.stop(scriptID: script.id)

print("Test completed!")