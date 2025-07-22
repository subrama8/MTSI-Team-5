import SwiftUI
import Foundation
import UserNotifications

// MARK: Frequency ------------------------------------------------------------
enum Frequency: Hashable, Codable {
    case daily
    case weekly(Set<Int>)                     // weekday numbers 1…7 (Sun-Sat)
    
    var description: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly(let days):
            // shortWeekdaySymbols can be optional on older SDKs ⇒ provide fallback
            let syms = DateFormatter().shortWeekdaySymbols ??
                       ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            return days.sorted().map { syms[$0 - 1] }.joined(separator: ", ")
        }
    }
}

// MARK: Medication -----------------------------------------------------------
final class Medication: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var color: Color
    @Published var times: [DateComponents]          // hour/minute
    @Published var frequency: Frequency
    @Published var cooldownMinutes: Int?
    
    init(name: String,
         color: Color,
         times: [DateComponents] = [],
         frequency: Frequency = .daily) {
        self.name      = name
        self.color     = color
        self.times     = times
        self.frequency = frequency
    }
    
    /// Next scheduled dose after a reference date
    func nextDose(after date: Date = .now) -> Date? {
        let cal = Calendar.current
        
        func next(for comps: DateComponents) -> Date? {
            switch frequency {
            case .daily:
                return cal.nextDate(after: date,
                                    matching: comps,
                                    matchingPolicy: .nextTime,
                                    direction: .forward)
            case .weekly(let days):
                return days
                    .compactMap { w -> Date? in
                        var c = comps; c.weekday = w
                        return cal.nextDate(after: date,
                                            matching: c,
                                            matchingPolicy: .nextTimePreservingSmallerComponents,
                                            direction: .forward)
                    }
                    .min()
            }
        }
        return times.compactMap(next).min()
    }
}

// MARK: Drop log -------------------------------------------------------------
struct DropEvent: Identifiable {
    let id   = UUID()
    let med  : Medication
    let date : Date
    let auto : Bool
}

@MainActor
final class DropLog: ObservableObject {
    @Published var events: [DropEvent] = []
    
    func record(_ med: Medication, auto: Bool) {
        events.append(DropEvent(med: med, date: .now, auto: auto))
    }
    
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        var count = 0
        while events.contains(where: { cal.isDate($0.date, inSameDayAs: day) }) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}

// MARK: MedicationSchedule ---------------------------------------------------
@MainActor
final class MedicationSchedule: ObservableObject {
    @Published var meds: [Medication] = []
    
    func add(_ med: Medication) async {
        meds.append(med)
        await scheduleNotifications(for: med)
    }
    
    // 10-minute-early alerts
    private func scheduleNotifications(for med: Medication) async {
        for t in med.times {
            switch med.frequency {
            case .daily:
                let dc = Self.offset(t, byMinutes: -10)
                if let fire = Calendar.current.date(from: dc) {
                    try? await LocalNotificationManager.shared.schedule(
                        id: "\(med.id)-\(t.hour ?? 0)-\(t.minute ?? 0)",
                        at: fire,
                        title: "Eye-drop in 10 min: \(med.name)")
                }
            case .weekly(let days):
                for w in days {
                    var dc = Self.offset(t, byMinutes: -10); dc.weekday = w
                    if let fire = Calendar.current.date(from: dc) {
                        try? await LocalNotificationManager.shared.schedule(
                            id: "\(med.id)-\(w)-\(t.hour ?? 0)-\(t.minute ?? 0)",
                            at: fire,
                            title: "Eye-drop in 10 min: \(med.name)")
                    }
                }
            }
        }
    }
    
    private static func offset(_ comps: DateComponents, byMinutes m: Int) -> DateComponents {
        var c = comps; c.minute = (c.minute ?? 0) + m
        return c
    }
    
    // demo dose
    func seedDemoData() async {
        guard meds.isEmpty else { return }
        let date  = Date().addingTimeInterval(60)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let demo  = Medication(name: "Timolol", color: .blue, times: [comps])
        await add(demo)
    }
}
