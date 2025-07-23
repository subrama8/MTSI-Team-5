import UserNotifications
import Foundation
import UIKit

@MainActor
final class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = LocalNotificationManager()
    
    @Published var isAuthorized = false
    @Published var pushToken: String?
    
    // Notification preferences
    @Published var notifyBefore = true      // 10 minutes before
    @Published var notifyAtTime = true      // At exact time
    @Published var notifyAfter = true       // 10 minutes after
    
    override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // ── permission
    func requestAuth() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        isAuthorized = granted
        if !granted { 
            print("🔔 user declined notifications") 
        } else {
            await registerForPushNotifications()
        }
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
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        pushToken = tokenString
        print("📱 Push token: \(tokenString)")
        // In production, send this token to your server
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

    // ── Smart scheduling with logging check
    func scheduleWithLoggingCheck(id: String, at date: Date, title: String, body: String? = nil, medicationId: String? = nil, checkLogging: Bool = true) async throws {
        // Skip scheduling if medication was already logged for this time period
        if checkLogging, let medId = medicationId, await isMedicationAlreadyLogged(medId: medId, scheduledTime: date) {
            print("⏭️ Skipping notification - medication already logged: \(title)")
            return
        }
        
        try await schedule(id: id, at: date, title: title, body: body, medicationId: medicationId)
    }
    
    // ── schedule helper
    func schedule(id: String, at date: Date, title: String, body: String? = nil, medicationId: String? = nil) async throws {
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trig  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let c     = UNMutableNotificationContent()
        c.title   = title
        c.body    = body ?? "Time to take your eye medication"
        c.sound   = .default
        c.badge   = 1
        c.categoryIdentifier = "EYE_REMIND"
        
        // Add user info for tracking
        if let medId = medicationId {
            c.userInfo = ["medicationId": medId, "type": "medication_reminder"]
        }
        
        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: c, trigger: trig))
    }
    
    // ── Critical alerts for missed doses
    func scheduleCriticalAlert(id: String, title: String, body: String, delayMinutes: Int = 30) async throws {
        let fireDate = Date().addingTimeInterval(TimeInterval(delayMinutes * 60))
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fireDate)
        let trig  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        content.badge = 1
        content.categoryIdentifier = "MISSED_DOSE"
        content.userInfo = ["type": "missed_dose", "severity": "high"]
        
        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trig))
    }
    
    // ── Recurring notifications
    func scheduleRecurring(id: String, title: String, body: String, dateComponents: DateComponents) async throws {
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "EYE_REMIND"
        content.userInfo = ["type": "recurring_reminder"]
        
        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
    
    // ── Cancel specific notification
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    // ── Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // ── Get pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    // ── delegate: actions
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive r: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let userInfo = r.notification.request.content.userInfo
        
        switch r.actionIdentifier {
        case "MARK_DONE":
            // Mark medication as taken
            if let medicationId = userInfo["medicationId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MedicationTaken"),
                    object: nil,
                    userInfo: ["medicationId": medicationId]
                )
                
                // Cancel any remaining notifications for this medication today
                // This will be handled by the DropLog.record() method
            }
            
        case "SNOOZE_15":
            let d = Date().addingTimeInterval(900)
            let title = r.notification.request.content.title
            let body = r.notification.request.content.body
            let medicationId = userInfo["medicationId"] as? String
            
            Task { 
                try? await schedule(
                    id: UUID().uuidString, 
                    at: d, 
                    title: title,
                    body: body,
                    medicationId: medicationId
                ) 
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            if let type = userInfo["type"] as? String {
                switch type {
                case "medication_reminder":
                    // Open to medication screen
                    NotificationCenter.default.post(name: NSNotification.Name("OpenMedication"), object: nil)
                case "missed_dose":
                    // Open to log screen
                    NotificationCenter.default.post(name: NSNotification.Name("OpenLogScreen"), object: nil)
                default:
                    break
                }
            }
            
        default: break
        }
        
        // Clear badge when notification is handled
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        done()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions)->Void) {
        // Show notification even when app is in foreground
        done([.banner, .sound, .badge])
    }
    
    // ── Handle push notification registration
    func handlePushRegistration(result: Result<Data, Error>) {
        switch result {
        case .success(let token):
            setPushToken(token)
        case .failure(let error):
            print("❌ Failed to register for push notifications: \(error)")
        }
    }
    
    // ── Handle incoming push notifications
    func handlePushNotification(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any] else { return }
        
        // Extract custom data
        if let customData = userInfo["custom_data"] as? [String: Any] {
            switch customData["type"] as? String {
            case "medication_reminder":
                // Handle medication reminder from server
                break
            case "caregiver_alert":
                // Handle caregiver alert
                break
            case "device_status":
                // Handle device status update
                break
            default:
                break
            }
        }
        
        // Update badge count
        if let badge = aps["badge"] as? Int {
            Task { @MainActor in
                UIApplication.shared.applicationIconBadgeNumber = badge
            }
        }
    }
    
    // ── Check if medication was already logged
    private func isMedicationAlreadyLogged(medId: String, scheduledTime: Date) async -> Bool {
        // Check if notification center has access to the drop log
        // This is a basic check - in production you'd want to inject the DropLog dependency
        
        // For now, we'll use a simple approach: check if the time has passed and assume it was logged
        // In a full implementation, you'd need to access the DropLog service
        // This prevents spamming past notifications
        if scheduledTime < Date().addingTimeInterval(-3600) { // 1 hour ago
            return true // Assume old notifications shouldn't fire
        }
        
        return false
    }
    
    // ── Cancel notifications for a specific medication time
    func cancelNotificationsForMedication(medicationId: String, time: DateComponents) {
        let timeId = "\(time.hour ?? 0)_\(time.minute ?? 0)"
        
        // Cancel all three types of notifications for this specific time
        cancelNotification(id: "\(medicationId)_before_\(timeId)")
        cancelNotification(id: "\(medicationId)_exact_\(timeId)")
        cancelNotification(id: "\(medicationId)_after_\(timeId)")
    }
}
