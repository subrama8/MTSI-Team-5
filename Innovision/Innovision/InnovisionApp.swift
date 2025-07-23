import SwiftUI
import UserNotifications

@main
struct InnovisionApp: App {
    @StateObject private var schedule = MedicationSchedule()
    @StateObject private var log      = DropLog()
    @StateObject private var device   = DeviceService()
    @StateObject private var conflictDetector = ConflictDetector()
    @StateObject private var caregiverService = CaregiverService()
    @StateObject private var pdfExporter = PDFExporter()
    @StateObject private var bleService = BLEService()
    @StateObject private var notificationManager = LocalNotificationManager.shared

    /// Empty string means "not logged in yet"
    @AppStorage("username") private var username = ""
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        LocalNotificationManager.shared.registerCategories()
        UNUserNotificationCenter.current().delegate = LocalNotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if username.isEmpty {
                    LoginView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(schedule)
            .environmentObject(log)
            .environmentObject(device)
            .environmentObject(conflictDetector)
            .environmentObject(caregiverService)
            .environmentObject(pdfExporter)
            .environmentObject(bleService)
            .environmentObject(notificationManager)
            .tint(.skyBlue)
            .modifier(SeniorFont())
            .task {
                // Ask notif permission just once after first login
                if !username.isEmpty {
                    try? await LocalNotificationManager.shared.requestAuth()
                    await schedule.seedDemoData()
                    
                    // Check for conflicts when medications change
                    conflictDetector.checkConflicts(for: schedule.meds)
                }
            }
            .onChange(of: schedule.meds) { newMeds in
                conflictDetector.checkConflicts(for: newMeds)
                
                // Send conflict alerts to caregivers
                for conflict in conflictDetector.conflicts {
                    if conflict.severity == .high || conflict.severity == .severe {
                        caregiverService.createConflictAlert(conflict: conflict)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MedicationTaken"))) { notification in
                if let userInfo = notification.userInfo,
                   let medicationId = userInfo["medicationId"] as? String,
                   let medication = schedule.meds.first(where: { $0.id.uuidString == medicationId }) {
                    log.record(medication, auto: false)
                }
            }
        }
    }
}

// MARK: - AppDelegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        LocalNotificationManager.shared.handlePushRegistration(result: .success(deviceToken))
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LocalNotificationManager.shared.handlePushRegistration(result: .failure(error))
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        LocalNotificationManager.shared.handlePushNotification(userInfo: userInfo)
        completionHandler(.newData)
    }
}
