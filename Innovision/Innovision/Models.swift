import SwiftUI
import Foundation
import UserNotifications

// ────────── FREQUENCY ──────────
enum Frequency: Hashable, Codable {
    case daily
    case weekly(Set<Int>)          // weekday numbers 1…7 (Sun‑Sat)

    var description: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly(let days):
            let syms = DateFormatter().shortWeekdaySymbols ??
                       ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            return days.sorted().map { syms[$0 - 1] }.joined(separator: ", ")
        }
    }
}

// ────────── MEDICATION ──────────
final class Medication: Identifiable, ObservableObject, Equatable {
    let id = UUID()

    @Published var name: String
    @Published var color: Color
    @Published var times: [DateComponents]         // hour/min only
    @Published var frequency: Frequency

    init(name: String,
         color: Color,
         times: [DateComponents] = [],
         frequency: Frequency = .daily) {
        self.name = name
        self.color = color
        self.times = times
        self.frequency = frequency
    }

    /// Next dose after now
    func nextDose(after date: Date = .now) -> Date? {
        let cal = Calendar.current
        func next(_ t: DateComponents) -> Date? {
            switch frequency {
            case .daily:
                return cal.nextDate(after: date, matching: t,
                                    matchingPolicy: .nextTime, direction: .forward)
            case .weekly(let set):
                return set.compactMap { w -> Date? in
                    var c = t; c.weekday = w
                    return cal.nextDate(after: date, matching: c,
                                        matchingPolicy: .nextTimePreservingSmallerComponents,
                                        direction: .forward)
                }.min()
            }
        }
        return times.compactMap(next).min()
    }
    
    // MARK: - Equatable
    static func == (lhs: Medication, rhs: Medication) -> Bool {
        return lhs.id == rhs.id
    }
}

// ────────── DROP LOG ──────────
struct DropEvent: Identifiable {
    let id = UUID()
    let med: Medication
    let date: Date
}

@MainActor
final class DropLog: ObservableObject {
    @Published var events: [DropEvent] = []

    func record(_ med: Medication, auto _: Bool) {
        events.append(DropEvent(med: med, date: .now))
        
        // Cancel remaining notifications for this medication today
        cancelRemainingNotifications(for: med)
    }
    
    /// Cancel any remaining notifications for today if medication was logged
    private func cancelRemainingNotifications(for med: Medication) {
        let medicationId = med.id.uuidString
        let now = Date()
        let calendar = Calendar.current
        
        for time in med.times {
            let timeId = "\(time.hour ?? 0)_\(time.minute ?? 0)"
            
            // Check if the current dose time is today
            guard let doseTime = calendar.date(from: time),
                  calendar.isDate(doseTime, inSameDayAs: now) else {
                continue
            }
            
            // Cancel all three notification types if they haven't fired yet
            switch med.frequency {
            case .daily:
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_before_\(timeId)")
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_exact_\(timeId)")
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_after_\(timeId)")
                
            case .weekly(let days):
                let currentWeekday = calendar.component(.weekday, from: now)
                if days.contains(currentWeekday) {
                    let weekdayTimeId = "\(currentWeekday)_\(timeId)"
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_before_\(weekdayTimeId)")
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_exact_\(weekdayTimeId)")
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_after_\(weekdayTimeId)")
                }
            }
        }
    }

    func takenToday(for med: Medication) -> Int {
        let cal = Calendar.current
        return events.filter { $0.med.id == med.id && cal.isDateInToday($0.date) }.count
    }

    func streak(for med: Medication, schedule: MedicationSchedule) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        var count = 0
        while true {
            let expected = schedule.expectedDoses(for: med, on: day)
            let taken = events.filter {
                $0.med.id == med.id && cal.isDate($0.date, inSameDayAs: day)
            }.count
            guard expected > 0, taken >= expected else { break }
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}

// ────────── MEDICATION SCHEDULE ──────────
@MainActor
final class MedicationSchedule: ObservableObject {
    @Published var meds: [Medication] = []

    /// How many doses are expected for `med` on a specific day
    func expectedDoses(for med: Medication, on day: Date = .now) -> Int {
        let cal = Calendar.current
        switch med.frequency {
        case .daily:
            return med.times.count
        case .weekly(let set):
            let wd = cal.component(.weekday, from: day)
            return set.contains(wd) ? med.times.count : 0
        }
    }

    // MARK: Add + schedule
    func add(_ med: Medication) async {
        meds.append(med)
        await scheduleEnhancedNotifications(for: med)
    }
    
    func updateMedication(_ med: Medication) async {
        // Cancel existing notifications for this medication
        await cancelNotifications(for: med)
        // Schedule new notifications
        await scheduleEnhancedNotifications(for: med)
    }
    
    func removeMedication(_ med: Medication) async {
        meds.removeAll { $0.id == med.id }
        await cancelNotifications(for: med)
    }
    
    private func cancelNotifications(for med: Medication) async {
        let medicationId = med.id.uuidString
        for time in med.times {
            let timeId = "\(time.hour ?? 0)_\(time.minute ?? 0)"
            
            switch med.frequency {
            case .daily:
                // Cancel all three types of notifications
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_before_\(timeId)")
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_exact_\(timeId)")
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_after_\(timeId)")
                
                // Cancel old notification IDs for backwards compatibility
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_warning_\(timeId)")
                LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_missed_\(timeId)")
                
            case .weekly(let days):
                for weekday in days {
                    let weekdayTimeId = "\(weekday)_\(timeId)"
                    
                    // Cancel all three types of notifications
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_before_\(weekdayTimeId)")
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_exact_\(weekdayTimeId)")
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_after_\(weekdayTimeId)")
                    
                    // Cancel old notification IDs for backwards compatibility
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_warning_\(weekdayTimeId)")
                    LocalNotificationManager.shared.cancelNotification(id: "\(medicationId)_missed_\(weekdayTimeId)")
                }
            }
        }
    }
    
    /// Enhanced notification scheduling with three-phase alerts (before/at/after)
    private func scheduleEnhancedNotifications(for med: Medication) async {
        let notificationManager = LocalNotificationManager.shared
        
        for time in med.times {
            let medicationId = med.id.uuidString
            let timeId = "\(time.hour ?? 0)_\(time.minute ?? 0)"
            
            switch med.frequency {
            case .daily:
                // Schedule 10-minute before notification (if enabled)
                if notificationManager.notifyBefore,
                   let fireDate = Calendar.current.date(from: Self.offset(time, by: -10)) {
                    try? await notificationManager.scheduleWithLoggingCheck(
                        id: "\(medicationId)_before_\(timeId)",
                        at: fireDate,
                        title: "Eye‑drop in 10 min: \(med.name)",
                        body: "Prepare your \(med.name) eye drops",
                        medicationId: medicationId
                    )
                }
                
                // Schedule exact time notification (if enabled)
                if notificationManager.notifyAtTime,
                   let exactDate = Calendar.current.date(from: time) {
                    try? await notificationManager.scheduleWithLoggingCheck(
                        id: "\(medicationId)_exact_\(timeId)",
                        at: exactDate,
                        title: "Time for \(med.name)",
                        body: "Take your eye drops now",
                        medicationId: medicationId
                    )
                }
                
                // Schedule 10-minute after notification (if enabled)
                if notificationManager.notifyAfter,
                   let fireDate = Calendar.current.date(from: Self.offset(time, by: 10)) {
                    try? await notificationManager.scheduleWithLoggingCheck(
                        id: "\(medicationId)_after_\(timeId)",
                        at: fireDate,
                        title: "Don't forget: \(med.name)",
                        body: "Did you take your \(med.name) eye drops?",
                        medicationId: medicationId
                    )
                }

            case .weekly(let days):
                for weekday in days {
                    let weekdayTimeId = "\(weekday)_\(timeId)"
                    
                    // Schedule 10-minute before notification (if enabled)
                    if notificationManager.notifyBefore {
                        var warningComps = Self.offset(time, by: -10)
                        warningComps.weekday = weekday
                        if let fireDate = Calendar.current.date(from: warningComps) {
                            try? await notificationManager.scheduleWithLoggingCheck(
                                id: "\(medicationId)_before_\(weekdayTimeId)",
                                at: fireDate,
                                title: "Eye‑drop in 10 min: \(med.name)",
                                body: "Prepare your \(med.name) eye drops",
                                medicationId: medicationId
                            )
                        }
                    }
                    
                    // Schedule exact time notification (if enabled)
                    if notificationManager.notifyAtTime {
                        var exactComps = time
                        exactComps.weekday = weekday
                        if let exactDate = Calendar.current.date(from: exactComps) {
                            try? await notificationManager.scheduleWithLoggingCheck(
                                id: "\(medicationId)_exact_\(weekdayTimeId)",
                                at: exactDate,
                                title: "Time for \(med.name)",
                                body: "Take your eye drops now",
                                medicationId: medicationId
                            )
                        }
                    }
                    
                    // Schedule 10-minute after notification (if enabled)
                    if notificationManager.notifyAfter {
                        var afterComps = Self.offset(time, by: 10)
                        afterComps.weekday = weekday
                        if let fireDate = Calendar.current.date(from: afterComps) {
                            try? await notificationManager.scheduleWithLoggingCheck(
                                id: "\(medicationId)_after_\(weekdayTimeId)",
                                at: fireDate,
                                title: "Don't forget: \(med.name)",
                                body: "Did you take your \(med.name) eye drops?",
                                medicationId: medicationId
                            )
                        }
                    }
                }
            }
        }
    }

    /// Creates 10‑minute‑early local notifications for each dose time.
    private func scheduleNotifications(for med: Medication) async {
        for time in med.times {
            switch med.frequency {
            case .daily:
                if let fireDate = Calendar.current.date(from: Self.offset(time, by: -10)) {
                    try? await LocalNotificationManager.shared.schedule(
                        id: UUID().uuidString,
                        at: fireDate,
                        title: "Eye‑drop in 10 min: \(med.name)")
                }

            case .weekly(let days):
                for weekday in days {
                    var comps = Self.offset(time, by: -10)
                    comps.weekday = weekday
                    if let fireDate = Calendar.current.date(from: comps) {
                        try? await LocalNotificationManager.shared.schedule(
                            id: UUID().uuidString,
                            at: fireDate,
                            title: "Eye‑drop in 10 min: \(med.name)")
                    }
                }
            }
        }
    }

    /// Helper to shift minutes safely with bounds checking
    private static func offset(_ comps: DateComponents, by minutes: Int) -> DateComponents {
        var c = comps
        let currentMinute = c.minute ?? 0
        let newMinute = currentMinute + minutes
        
        if newMinute < 0 {
            c.hour = (c.hour ?? 0) - 1
            c.minute = 60 + newMinute
        } else if newMinute >= 60 {
            c.hour = (c.hour ?? 0) + (newMinute / 60)
            c.minute = newMinute % 60
        } else {
            c.minute = newMinute
        }
        
        return c
    }

    // MARK: Demo seed
    func seedDemoData() async {
        guard meds.isEmpty else { return }
        let date  = Date().addingTimeInterval(20 * 60) // 20 minutes from now
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let demo  = Medication(name: "Timolol", color: .blue, times: [comps])
        await add(demo)
    }
}
