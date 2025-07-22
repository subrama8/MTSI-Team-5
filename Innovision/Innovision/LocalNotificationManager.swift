import UserNotifications

actor LocalNotificationManager {
    static let shared = LocalNotificationManager()

    // permission
    func requestAuth() async throws {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw NSError(domain: "notif", code: 1) }
    }

    // one-off local alert
    func schedule(id: String, at date: Date, title: String) async throws {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                    from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default

        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id,
                                       content: content,
                                       trigger: trigger))
    }

    func cancel(ids: [String]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }
}
