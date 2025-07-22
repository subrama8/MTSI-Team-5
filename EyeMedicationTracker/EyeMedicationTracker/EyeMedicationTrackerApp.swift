import SwiftUI
import UserNotifications

@main
struct EyeMedicationTrackerApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Request notification permissions
        requestNotificationPermission()
        
        // Configure accessibility
        configureAccessibility()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(NotificationManager.shared)
                .environmentObject(ArduinoService.shared)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
                DispatchQueue.main.async {
                    NotificationManager.shared.scheduleUpcomingNotifications()
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func configureAccessibility() {
        // Configure for larger text sizes and accessibility
        if UIAccessibility.isBoldTextEnabled {
            // Adjust UI for bold text
        }
        
        if UIAccessibility.isReduceMotionEnabled {
            // Reduce animations
        }
    }
}