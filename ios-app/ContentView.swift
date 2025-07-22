import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            HistoryView()
                .tabItem { Label("History", systemImage: "checkmark.seal") }
        }
    }
} 