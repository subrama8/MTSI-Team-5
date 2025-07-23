import Foundation
import SwiftUI

struct MedicationConflict {
    let medication1: Medication
    let medication2: Medication
    let conflictType: ConflictType
    let severity: Severity
    let description: String
    
    enum ConflictType {
        case interaction
        case timing
        case dosage
    }
    
    enum Severity {
        case low, moderate, high, severe
        
        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .severe: return .red
            }
        }
    }
}

@MainActor
final class ConflictDetector: ObservableObject {
    @Published var conflicts: [MedicationConflict] = []
    
    private let knownInteractions: [String: [String: (MedicationConflict.ConflictType, MedicationConflict.Severity, String)]] = [
        "timolol": [
            "brimonidine": (.interaction, .moderate, "May increase risk of cardiovascular effects"),
            "dorzolamide": (.interaction, .low, "Generally safe combination, monitor for increased side effects")
        ],
        "latanoprost": [
            "timolol": (.timing, .low, "Can be used together, separate administration by 5 minutes"),
            "brimonidine": (.timing, .low, "Can be used together, separate administration by 5 minutes")
        ],
        "brimonidine": [
            "timolol": (.interaction, .moderate, "May increase risk of cardiovascular effects"),
            "latanoprost": (.timing, .low, "Can be used together, separate administration by 5 minutes")
        ]
    ]
    
    func checkConflicts(for medications: [Medication]) {
        conflicts.removeAll()
        
        for i in 0..<medications.count {
            for j in (i+1)..<medications.count {
                let med1 = medications[i]
                let med2 = medications[j]
                
                if let conflict = checkInteraction(between: med1, and: med2) {
                    conflicts.append(conflict)
                }
                
                if let timingConflict = checkTimingConflict(between: med1, and: med2) {
                    conflicts.append(timingConflict)
                }
            }
        }
    }
    
    private func checkInteraction(between med1: Medication, and med2: Medication) -> MedicationConflict? {
        let name1 = med1.name.lowercased()
        let name2 = med2.name.lowercased()
        
        if let interactions = knownInteractions[name1],
           let (type, severity, description) = interactions[name2] {
            return MedicationConflict(
                medication1: med1,
                medication2: med2,
                conflictType: type,
                severity: severity,
                description: description
            )
        }
        
        if let interactions = knownInteractions[name2],
           let (type, severity, description) = interactions[name1] {
            return MedicationConflict(
                medication1: med2,
                medication2: med1,
                conflictType: type,
                severity: severity,
                description: description
            )
        }
        
        return nil
    }
    
    private func checkTimingConflict(between med1: Medication, and med2: Medication) -> MedicationConflict? {
        let calendar = Calendar.current
        
        for time1 in med1.times {
            for time2 in med2.times {
                let date1 = calendar.date(from: time1) ?? Date()
                let date2 = calendar.date(from: time2) ?? Date()
                
                let timeDifference = abs(date1.timeIntervalSince(date2))
                
                if timeDifference < 300 { // Less than 5 minutes apart
                    return MedicationConflict(
                        medication1: med1,
                        medication2: med2,
                        conflictType: .timing,
                        severity: .moderate,
                        description: "Medications scheduled too close together. Consider spacing doses by at least 5 minutes."
                    )
                }
            }
        }
        
        return nil
    }
    
    func hasHighSeverityConflicts() -> Bool {
        return conflicts.contains { $0.severity == .high || $0.severity == .severe }
    }
    
    func conflictCount(for severity: MedicationConflict.Severity) -> Int {
        return conflicts.filter { $0.severity == severity }.count
    }
}
