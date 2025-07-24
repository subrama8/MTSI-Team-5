import UserNotifications
import Foundation
import UIKit
import SwiftUI

@MainActor
final class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {

    // MARK: – Published state
    static let shared = LocalNotificationManager()
    @Published var isAuthorized   = false
    @Published var pushToken      : String?

    // Lead-time before/after a dose (minutes)
    @Published var reminderLeadTime: Int = 10

    // Which phases should fire?
    @Published var notifyBefore  = true   // reminderLeadTime min before dose
    @Published var notifyAtTime  = true   // exactly at dose time
    @Published var notifyAfter   = true   // reminderLeadTime min after dose

    // MARK: – Lifecycle
    override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: – Permission
    func requestAuth() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge, .provisional])
        isAuthorized = granted
        if granted { await registerForPushNotifications() }
    }

    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    @MainActor
    private func registerForPushNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func setPushToken(_ token: Data) {
        let str = token.map { String(format: "%02.2hhx", $0) }.joined()
        pushToken = str
        print("📱 Push token:", str)
    }

    // MARK: – Categories
    func registerCategories() {
        let done   = UNNotificationAction(identifier: "MARK_DONE",
                                          title: "Done",
                                          options: [.authenticationRequired])
        let snooze = UNNotificationAction(identifier: "SNOOZE_15",
                                          title: "Snooze 15 min",
                                          options: [])
        let cat = UNNotificationCategory(identifier: "EYE_REMIND",
                                         actions: [done, snooze],
                                         intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    // MARK: – Scheduling helpers
    func scheduleWithLoggingCheck(
        id: String,
        at date: Date,
        title: String,
        body: String? = nil,
        medicationId: String? = nil,
        checkLogging: Bool = true
    ) async throws {
        if checkLogging,
           let medId = medicationId,
           await isMedicationAlreadyLogged(medId: medId, scheduledTime: date) {
            print("⏭️ Skipping – already logged:", title)
            return
        }
        try await schedule(id: id, at: date, title: title,
                           body: body, medicationId: medicationId)
    }

    func schedule(
        id: String,
        at date: Date,
        title: String,
        body: String? = nil,
        medicationId: String? = nil
    ) async throws {
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let c = UNMutableNotificationContent()
        c.title = title
        c.body  = body ?? "Time to take your eye medication"
        c.sound = .default
        c.badge = 1
        c.categoryIdentifier = "EYE_REMIND"
        if let medId = medicationId {
            c.userInfo = ["medicationId": medId,
                          "type": "medication_reminder"]
        }

        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id,
                                       content: c,
                                       trigger: trig))
    }

    // MARK: – Utility offset
    func minutesOffset(_ minutes: Int,
                       from comps: DateComponents) -> DateComponents {
        var c = comps
        let total = (c.minute ?? 0) + minutes
        c.hour   = (c.hour ?? 0) + total / 60
        c.minute = (total % 60 + 60) % 60
        return c
    }

    // MARK: – Cancel
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
    func cancelAllNotifications() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }

    // MARK: – Pending lookup
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    // MARK: – Delegate
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive resp: UNNotificationResponse,
                            withCompletionHandler done: @escaping () -> Void) {
        let info = resp.notification.request.content.userInfo
        switch resp.actionIdentifier {
        case "MARK_DONE":
            if let medId = info["medicationId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MedicationTaken"),
                    object: nil,
                    userInfo: ["medicationId": medId])
            }
        case "SNOOZE_15":
            if let title = resp.notification.request.content.title as String?,
               let body  = resp.notification.request.content.body as String? {
                Task {
                    try? await schedule(id: UUID().uuidString,
                                        at: Date().addingTimeInterval(900),
                                        title: title,
                                        body: body,
                                        medicationId: info["medicationId"] as? String)
                }
            }
        default: break
        }
        Task { @MainActor in UIApplication.shared.applicationIconBadgeNumber = 0 }
        done()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent _: UNNotification,
                            withCompletionHandler done: @escaping (UNNotificationPresentationOptions)->Void) {
        done([.banner, .sound, .badge])
    }

    // MARK: – Push registration / receipt
    func handlePushRegistration(result: Result<Data, Error>) {
        switch result {
        case .success(let data): setPushToken(data)
        case .failure(let e):    print("❌ Push reg failed:", e)
        }
    }
    func handlePushNotification(userInfo: [AnyHashable : Any]) {
        if let aps = userInfo["aps"] as? [String: Any],
           let badge = aps["badge"] as? Int {
            Task { @MainActor in UIApplication.shared.applicationIconBadgeNumber = badge }
        }
    }

    // MARK: – Log-aware skip helper
    private func isMedicationAlreadyLogged(
        medId: String,
        scheduledTime: Date
    ) async -> Bool {
        if scheduledTime < Date().addingTimeInterval(-3600) { return true }
        return false
    }
}
