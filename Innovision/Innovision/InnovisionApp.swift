import SwiftUI
import UserNotifications
import UIKit

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

@main
struct InnovisionApp: App {
    @StateObject private var schedule         = MedicationSchedule()
    @StateObject private var log              = DropLog()
    @StateObject private var device           = DeviceService()
    @StateObject private var conflictDetector = ConflictDetector()
    @StateObject private var caregiverService = CaregiverService()
    @StateObject private var pdfExporter      = PDFExporter()
    @StateObject private var bleService       = BLEService()
    @StateObject private var notificationManager = LocalNotificationManager.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        LocalNotificationManager.shared.registerCategories()
        UNUserNotificationCenter.current().delegate = LocalNotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                    try? await notificationManager.requestAuth()
                    await schedule.seedDemoData()
                    conflictDetector.checkConflicts(for: schedule.meds)
                }
                .onChange(of: schedule.meds) { meds in
                    conflictDetector.checkConflicts(for: meds)
                    for c in conflictDetector.conflicts
                        where c.severity == .high || c.severity == .severe {
                        caregiverService.createConflictAlert(conflict: c)
                    }
                }
        }
    }
}
