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
final class Medication: Identifiable, ObservableObject {
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
        await scheduleNotifications(for: med)
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

    /// Helper to shift minutes
    private static func offset(_ comps: DateComponents, by minutes: Int) -> DateComponents {
        var c = comps
        c.minute = (c.minute ?? 0) + minutes
        return c
    }

    // MARK: Demo seed
    func seedDemoData() async {
        guard meds.isEmpty else { return }
        let date  = Date().addingTimeInterval(60)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let demo  = Medication(name: "Timolol", color: .blue, times: [comps])
        await add(demo)
    }
}
