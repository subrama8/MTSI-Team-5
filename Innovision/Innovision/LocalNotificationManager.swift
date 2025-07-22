import UserNotifications
import Foundation

final class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationManager()

    // ── permission
    func requestAuth() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if !granted { print("🔔 user declined notifications") }
    }

    // ── categories
    func registerCategories() {
        let done   = UNNotificationAction(identifier: "MARK_DONE",
                                          title: "Done",
                                          options: [.authenticationRequired])
        let snooze = UNNotificationAction(identifier: "SNOOZE_15",
                                          title: "Snooze 15 min",
                                          options: [])
        let cat = UNNotificationCategory(identifier: "EYE_REMIND",
                                         actions: [done, snooze],
                                         intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    // ── schedule helper
    func schedule(id: String, at date: Date, title: String) async throws {
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trig  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let c     = UNMutableNotificationContent()
        c.title   = title
        c.sound   = .default
        c.categoryIdentifier = "EYE_REMIND"
        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: c, trigger: trig))
    }

    // ── delegate: actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive r: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        switch r.actionIdentifier {
        case "SNOOZE_15":
            let d = Date().addingTimeInterval(900)
            Task { try? await schedule(id: UUID().uuidString, at: d, title: r.notification.request.content.title) }
        default: break
        }
        done()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions)->Void) {
        done([.banner, .sound])
    }
}
