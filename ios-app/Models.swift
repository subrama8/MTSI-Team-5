import Foundation
import SwiftUI

// MARK: – Medication + schedule
final class Medication: Identifiable, ObservableObject, Codable {
    let id = UUID()
    @Published var name: String
    @Published var color: Color
    @Published var times: [DateComponents]      // e.g. 08:00, 20:00
    @Published var cooldownMinutes: Int?        // for conflict warnings
    
    init(name: String, color: Color, times: [DateComponents], cooldownMinutes: Int? = nil) {
        self.name = name
        self.color = color
        self.times = times
        self.cooldownMinutes = cooldownMinutes
    }
}

@MainActor
final class MedicationSchedule: ObservableObject {
    @Published var meds: [Medication] = []
    
    func addDemoDose(delayMinutes: Int) async {
        let now    = Date()
        let demo   = Medication(name: "Timolol",
                                color: .blue,
                                times: [Calendar.current.dateComponents([.hour, .minute],
                                               from: now.addingTimeInterval(Double(delayMinutes)*60))])
        meds.append(demo)
        
        // schedule notification
        try? await LocalNotificationManager.shared.schedule(
            id: demo.id.uuidString,
            at: now.addingTimeInterval(Double(delayMinutes)*60),
            title: "Time for \(demo.name)!"
        )
    }
}

// MARK: – Drop log
struct DropEvent: Identifiable, Codable {
    let id = UUID()
    let medName: String
    let date: Date
    let autoDetected: Bool
}

@MainActor
final class DropLog: ObservableObject {
    @Published var events: [DropEvent] = []
    
    func record(_ med: Medication, auto: Bool) {
        events.append(DropEvent(medName: med.name, date: Date(), autoDetected: auto))
    }
    
    var streak: Int {
        let cal = Calendar.current
        var currentStreak = 0
        var date = Date()
        
        while events.contains(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            currentStreak += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return currentStreak
    }
} 