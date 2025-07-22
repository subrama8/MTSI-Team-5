import SwiftUI

@main
struct InnovisionApp: App {
    @StateObject private var schedule = MedicationSchedule()
    @StateObject private var drops    = DropLog()
    @StateObject private var device   = DeviceService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(schedule)
                .environmentObject(drops)
                .environmentObject(device)
                .accentColor(.blue)            // light-blue theme
                .task {
                    try? await LocalNotificationManager.shared.requestAuth()
                    await schedule.seedDemoData()
                }
        }
    }
}
