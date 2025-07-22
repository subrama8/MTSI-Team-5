import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var arduinoService: ArduinoService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DeviceControlView()
                .tabItem {
                    Image(systemName: "wifi")
                    Text("Device")
                }
                .tag(0)
            
            MedicationCalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
                .tag(1)
            
            MedicationLogView()
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text("History")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(Color("LightBlue"))
        .onAppear {
            // Configure tab bar appearance for accessibility
            configureTabBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh data when app becomes active
            notificationManager.scheduleUpcomingNotifications()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Configure for larger text when accessibility is enabled
        if UIAccessibility.isBoldTextEnabled {
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .font: UIFont.boldSystemFont(ofSize: 12)
            ]
        }
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(ArduinoService.shared)
}