import UserNotifications

actor LocalNotificationManager {
    static let shared = LocalNotificationManager()
    
    func requestAuth() async throws {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw NSError(domain: "notif", code: 1) }
    }
    
    func schedule(id: String, at date: Date, title: String) async throws {
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date), repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }
    
    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
} 
