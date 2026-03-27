import Foundation
import AppKit
import UserNotifications

class TestAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Daihon"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification failed: \(error)")
            } else {
                print("Notification sent successfully")
            }
        }
        
        // Also test fallback methods
        print("📢 Test Notification: This is a test notification from Daihon")
        NSSound.beep()
    }
}

// Initialize app
let app = NSApplication.shared
let delegate = TestAppDelegate()
app.delegate = delegate

// Configure notifications
let center = UNUserNotificationCenter.current()
center.delegate = delegate

// Request authorization
center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    print("Authorization granted: \(granted)")
    if let error = error {
        print("Authorization error: \(error)")
    }
    
    if granted {
        DispatchQueue.main.async {
            delegate.testNotification()
        }
    }
}

// Run the app
app.run()