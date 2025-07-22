import Foundation
import UserNotifications
import CoreData

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var settings: UNNotificationSettings?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Management
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            
            isAuthorized = granted
            await updateSettings()
            
            if granted {
                scheduleUpcomingNotifications()
            }
            
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.settings = settings
            self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
    }
    
    private func updateSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.settings = settings
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleUpcomingNotifications() {
        guard isAuthorized else { return }
        
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<MedicationSchedule> = MedicationSchedule.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let schedules = try context.fetch(request)
            
            for schedule in schedules {
                scheduleNotifications(for: schedule)
            }
            
            print("Scheduled notifications for \(schedules.count) medication schedules")
        } catch {
            print("Failed to fetch schedules for notifications: \(error)")
        }
    }
    
    private func scheduleNotifications(for schedule: MedicationSchedule) {
        guard let name = schedule.name,
              let times = schedule.times else { return }
        
        let timeArray = times.components(separatedBy: ",")
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for the next 7 days
        for dayOffset in 0..<7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            for timeString in timeArray {
                scheduleNotification(
                    for: schedule,
                    on: futureDate,
                    timeString: timeString,
                    medicationName: name
                )
            }
        }
    }
    
    private func scheduleNotification(
        for schedule: MedicationSchedule,
        on date: Date,
        timeString: String,
        medicationName: String
    ) {
        guard let doseTime = createDoseDate(from: timeString, on: date) else { return }
        
        let reminderMinutes = Int(schedule.reminderMinutes)
        guard let reminderTime = Calendar.current.date(
            byAdding: .minute,
            value: -reminderMinutes,
            to: doseTime
        ) else { return }
        
        // Only schedule if reminder time is in the future
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder: \(medicationName)"
        content.body = "Time to take \(schedule.dosage ?? "your medication") at \(formatTime(timeString))"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "scheduleId": schedule.id?.uuidString ?? "",
            "medicationName": medicationName,
            "doseTime": timeString,
            "reminderMinutes": reminderMinutes
        ]
        
        // Create notification actions
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Remind in 5min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Create trigger
        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        // Create request
        let identifier = "\(schedule.id?.uuidString ?? "unknown")_\(timeString)_\(date.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func createDoseDate(from timeString: String, on date: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: timeString) else { return nil }
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents)
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: timeString) else { return timeString }
        
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Your medication reminders are working correctly!"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            }
        }
    }
    
    // MARK: - Snooze Functionality
    
    func snoozeNotification(scheduleId: String, originalTime: String, minutes: Int = 5) {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder (Snoozed)"
        content.body = "Reminder: Time for your medication"
        content.sound = UNNotificationSound.default
        
        content.userInfo = [
            "scheduleId": scheduleId,
            "originalTime": originalTime,
            "snoozed": true
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let identifier = "snooze_\(scheduleId)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            handleCompleteAction(userInfo: userInfo)
            
        case "SNOOZE_ACTION":
            handleSnoozeAction(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            print("User tapped notification")
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    private func handleCompleteAction(userInfo: [AnyHashable: Any]) {
        guard let scheduleIdString = userInfo["scheduleId"] as? String,
              let scheduleId = UUID(uuidString: scheduleIdString) else { return }
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<MedicationSchedule> = MedicationSchedule.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", scheduleId as CVarArg)
        
        do {
            let schedules = try context.fetch(request)
            if let schedule = schedules.first {
                // Create automatic log
                MedicationLog.createAutomaticLog(
                    for: schedule,
                    deviceUsed: false,
                    context: context
                )
                
                try context.save()
                print("Marked medication as completed from notification")
            }
        } catch {
            print("Failed to mark medication as completed: \(error)")
        }
    }
    
    private func handleSnoozeAction(userInfo: [AnyHashable: Any]) {
        guard let scheduleIdString = userInfo["scheduleId"] as? String,
              let originalTime = userInfo["originalTime"] as? String else { return }
        
        snoozeNotification(scheduleId: scheduleIdString, originalTime: originalTime, minutes: 5)
        print("Snoozed medication reminder for 5 minutes")
    }
}