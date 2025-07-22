import SwiftUI

@main
struct EyeDroprAppApp: App {
    @StateObject private var schedule = MedicationSchedule()
    @StateObject private var drops    = DropLog()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(schedule)
                .environmentObject(drops)
                .task {                      // first-launch demo reminder
                    try? await LocalNotificationManager.shared.requestAuth()
                    await schedule.addDemoDose(delayMinutes: 1)
                }
        }
    }
} 