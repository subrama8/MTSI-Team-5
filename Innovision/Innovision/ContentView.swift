import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationView { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationView { ScheduleView() }
                .tabItem { Label("Schedule", systemImage: "calendar") }

            NavigationView { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
                
            NavigationView { NotificationSettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .background(Color.back)
    }
}
