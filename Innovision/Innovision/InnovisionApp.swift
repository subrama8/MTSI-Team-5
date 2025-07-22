import SwiftUI
import UserNotifications

@main
struct InnovisionApp: App {
    @StateObject private var schedule = MedicationSchedule()
    @StateObject private var log      = DropLog()
    @StateObject private var device   = DeviceService()

    /// Empty string means “not logged in yet”
    @AppStorage("username") private var username = ""

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
            .tint(.skyBlue)
            .modifier(SeniorFont())
            .task {
                // Ask notif permission just once after first login
                if !username.isEmpty {
                    try? await LocalNotificationManager.shared.requestAuth()
                    await schedule.seedDemoData()
                }
            }
        }
    }
}
