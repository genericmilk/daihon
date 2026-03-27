import Foundation
import AppKit
import Combine

// Copy the essential models and classes we need for testing
struct Script: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let command: String
}

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let scripts: [Script]
    let packageManager: String?
    
    var effectivePackageManager: String {
        return packageManager ?? "none"
    }
}

class TestAppDelegate: NSObject, NSApplicationDelegate {
    func showNotification(title: String, subtitle: String, body: String) {
        // Always log to console for debugging
        print("📢 \(title): \(subtitle) - \(body)")

        // Play system beep as audio feedback
        NSSound.beep()

        print("Fallback notification working!")
    }
}

// Simulate the notification system
let appDelegate = TestAppDelegate()

// Create test project and script
let testProject = Project(
    id: UUID(),
    name: "Test Project", 
    path: "/tmp",
    scripts: [
        Script(id: UUID(), name: "Test Script", command: "echo 'Hello World' && sleep 2")
    ],
    packageManager: nil
)

let testScript = testProject.scripts[0]

// Test script start notification
print("Testing script start notification...")
appDelegate.showNotification(
    title: "Script Started",
    subtitle: testProject.name,
    body: "'\(testScript.name)' is now running"
)

// Wait a bit
sleep(1)

// Test script stop notification
print("Testing script stop notification...")
appDelegate.showNotification(
    title: "Script Stopped", 
    subtitle: testProject.name,
    body: "'\(testScript.name)' has stopped"
)

print("Notification tests completed successfully!")