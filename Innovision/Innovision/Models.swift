import SwiftUI
import UserNotifications

// MARK: – Frequency
enum Frequency: Hashable, Codable {
    case daily
    case weekly(Set<Int>)                // weekday numbers 1…7 (Sun=1)

    var description: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly(let days):
            let syms = DateFormatter().shortWeekdaySymbols ?? []
            return days.sorted().map { syms[$0 - 1] }.joined(separator: ", ")
        }
    }
}

// MARK: – Medication
final class Medication: Identifiable, ObservableObject, Equatable {
    let id = UUID()

    @Published var name: String
    @Published var color: Color
    @Published var times: [DateComponents]      // hour/minute only
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

    func nextDose(after date: Date = .now) -> Date? {
        let cal = Calendar.current
        func next(_ t: DateComponents) -> Date? {
            switch frequency {
            case .daily:
                return cal.nextDate(after: date, matching: t,
                                    matchingPolicy: .nextTime,
                                    direction: .forward)
            case .weekly(let days):
                return days.compactMap { wd -> Date? in
                    var c = t; c.weekday = wd
                    return cal.nextDate(after: date, matching: c,
                                        matchingPolicy: .nextTimePreservingSmallerComponents,
                                        direction: .forward)
                }.min()
            }
        }
        return times.compactMap(next).min()
    }

    static func == (lhs: Medication, rhs: Medication) -> Bool { lhs.id == rhs.id }
}

// MARK: – DropLog
struct DropEvent: Identifiable {
    let id = UUID()
    let med : Medication
    let date: Date
}

@MainActor
final class DropLog: ObservableObject {
    @Published var events: [DropEvent] = []

    func record(_ med: Medication, auto _: Bool) {
        events.append(DropEvent(med: med, date: .now))
        cancelRemainingNotifications(for: med)
    }

    private func cancelRemainingNotifications(for med: Medication) {
        let manager = LocalNotificationManager.shared
        let id = med.id.uuidString
        for t in med.times {
            let tag = "\(t.hour ?? 0)_\(t.minute ?? 0)"
            manager.cancelNotification(id: "\(id)_before_\(tag)")
            manager.cancelNotification(id: "\(id)_exact_\(tag)")
            manager.cancelNotification(id: "\(id)_after_\(tag)")
        }
    }

    func takenToday(for med: Medication) -> Int {
        let cal = Calendar.current
        return events.filter { $0.med.id == med.id && cal.isDateInToday($0.date) }.count
    }

    func streak(for med: Medication, schedule: MedicationSchedule) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now); var count = 0
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

// MARK: – Schedule
@MainActor
final class MedicationSchedule: ObservableObject {
    @Published var meds: [Medication] = []

    func expectedDoses(for med: Medication, on day: Date = .now) -> Int {
        let cal = Calendar.current
        switch med.frequency {
        case .daily:
            return med.times.count
        case .weekly(let days):
            return days.contains(cal.component(.weekday, from: day))
                 ? med.times.count : 0
        }
    }

    // CRUD
    func add(_ med: Medication) async {
        meds.append(med)
        await scheduleEnhancedNotifications(for: med)
    }

    func updateMedication(_ med: Medication) async {
        await cancelNotifications(for: med)
        await scheduleEnhancedNotifications(for: med)
    }

    func removeMedication(_ med: Medication) async {
        meds.removeAll { $0.id == med.id }
        await cancelNotifications(for: med)
    }

    // MARK: – Notification handling
    private func cancelNotifications(for med: Medication) async {
        let manager = LocalNotificationManager.shared
        let id = med.id.uuidString
        for t in med.times {
            let tag = "\(t.hour ?? 0)_\(t.minute ?? 0)"
            switch med.frequency {
            case .daily:
                manager.cancelNotification(id: "\(id)_before_\(tag)")
                manager.cancelNotification(id: "\(id)_exact_\(tag)")
                manager.cancelNotification(id: "\(id)_after_\(tag)")
            case .weekly(let days):
                for wd in days {
                    let wdTag = "\(wd)_\(tag)"
                    manager.cancelNotification(id: "\(id)_before_\(wdTag)")
                    manager.cancelNotification(id: "\(id)_exact_\(wdTag)")
                    manager.cancelNotification(id: "\(id)_after_\(wdTag)")
                }
            }
        }
    }

    private func scheduleEnhancedNotifications(for med: Medication) async {
        let manager = LocalNotificationManager.shared
        let lead = manager.reminderLeadTime

        for time in med.times {
            let medID  = med.id.uuidString
            let tag    = "\(time.hour ?? 0)_\(time.minute ?? 0)"

            func comps(_ delta: Int) -> DateComponents {
                manager.minutesOffset(delta, from: time)
            }

            switch med.frequency {
            case .daily:
                if manager.notifyBefore,
                   let d = Calendar.current.date(from: comps(-lead)) {
                    try? await manager.scheduleWithLoggingCheck(
                        id: "\(medID)_before_\(tag)",
                        at: d,
                        title: "Eye-drop in \(lead) min: \(med.name)",
                        body: "Prepare your \(med.name) drops",
                        medicationId: medID)
                }
                if manager.notifyAtTime,
                   let d = Calendar.current.date(from: time) {
                    try? await manager.scheduleWithLoggingCheck(
                        id: "\(medID)_exact_\(tag)",
                        at: d,
                        title: "Time for \(med.name)",
                        body: "Take your eye drops now",
                        medicationId: medID)
                }
                if manager.notifyAfter,
                   let d = Calendar.current.date(from: comps(+lead)) {
                    try? await manager.scheduleWithLoggingCheck(
                        id: "\(medID)_after_\(tag)",
                        at: d,
                        title: "Don't forget: \(med.name)",
                        body: "Did you take your \(med.name) drops?",
                        medicationId: medID)
                }

            case .weekly(let days):
                for wd in days {
                    let wdTag = "\(wd)_\(tag)"
                    if manager.notifyBefore {
                        var c = comps(-lead); c.weekday = wd
                        if let d = Calendar.current.date(from: c) {
                            try? await manager.scheduleWithLoggingCheck(
                                id: "\(medID)_before_\(wdTag)",
                                at: d,
                                title: "Eye-drop in \(lead) min: \(med.name)",
                                body: "Prepare your \(med.name) drops",
                                medicationId: medID)
                        }
                    }
                    if manager.notifyAtTime {
                        var c = time; c.weekday = wd
                        if let d = Calendar.current.date(from: c) {
                            try? await manager.scheduleWithLoggingCheck(
                                id: "\(medID)_exact_\(wdTag)",
                                at: d,
                                title: "Time for \(med.name)",
                                body: "Take your eye drops now",
                                medicationId: medID)
                        }
                    }
                    if manager.notifyAfter {
                        var c = comps(+lead); c.weekday = wd
                        if let d = Calendar.current.date(from: c) {
                            try? await manager.scheduleWithLoggingCheck(
                                id: "\(medID)_after_\(wdTag)",
                                at: d,
                                title: "Don't forget: \(med.name)",
                                body: "Did you take your \(med.name) drops?",
                                medicationId: medID)
                        }
                    }
                }
            }
        }
    }

    // MARK: – Demo seed
    func seedDemoData() async {
        guard meds.isEmpty else { return }
        let date  = Date().addingTimeInterval(20 * 60)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let demo  = Medication(name: "Timolol", color: .blue, times: [comps])
        await add(demo)
    }

    // MARK: – Legacy offset used in older helper
    private static func offset(_ comps: DateComponents, by minutes: Int) -> DateComponents {
        var c = comps
        let new = (c.minute ?? 0) + minutes
        c.hour   = (c.hour ?? 0) + new / 60
        c.minute = (new % 60 + 60) % 60
        return c
    }
}
