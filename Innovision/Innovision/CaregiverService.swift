import Foundation
import SwiftUI

struct CaregiverContact {
    let id = UUID()
    let name: String
    let email: String
    let phone: String
    let relationship: String
    let isEmergencyContact: Bool
}

struct MedicationAlert {
    let id = UUID()
    let type: AlertType
    let message: String
    let timestamp: Date
    let severity: Severity
    
    enum AlertType {
        case missedDose
        case conflict
        case sideEffect
        case deviceIssue
    }
    
    enum Severity {
        case low, medium, high, critical
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

@MainActor
final class CaregiverService: ObservableObject {
    @Published var caregivers: [CaregiverContact] = []
    @Published var alerts: [MedicationAlert] = []
    @Published var isNotificationEnabled = false
    
    func addCaregiver(_ caregiver: CaregiverContact) {
        caregivers.append(caregiver)
    }
    
    func removeCaregiver(id: UUID) {
        caregivers.removeAll { $0.id == id }
    }
    
    func sendAlert(_ alert: MedicationAlert) {
        alerts.append(alert)
        
        if isNotificationEnabled && alert.severity == .critical {
            notifyEmergencyContacts(alert: alert)
        }
    }
    
    func createMissedDoseAlert(for medication: String) {
        let alert = MedicationAlert(
            type: .missedDose,
            message: "Missed dose alert: \(medication) was not taken as scheduled",
            timestamp: Date(),
            severity: .medium
        )
        sendAlert(alert)
    }
    
    func createConflictAlert(conflict: MedicationConflict) {
        let severity: MedicationAlert.Severity = switch conflict.severity {
        case .low: .low
        case .moderate: .medium
        case .high: .high
        case .severe: .critical
        }
        
        let alert = MedicationAlert(
            type: .conflict,
            message: "Medication conflict: \(conflict.medication1.name) and \(conflict.medication2.name) - \(conflict.description)",
            timestamp: Date(),
            severity: severity
        )
        sendAlert(alert)
    }
    
    func createDeviceAlert(message: String) {
        let alert = MedicationAlert(
            type: .deviceIssue,
            message: "Device issue: \(message)",
            timestamp: Date(),
            severity: .high
        )
        sendAlert(alert)
    }
    
    private func notifyEmergencyContacts(alert: MedicationAlert) {
        let emergencyContacts = caregivers.filter { $0.isEmergencyContact }
        
        for contact in emergencyContacts {
            sendEmailNotification(to: contact, alert: alert)
            sendSMSNotification(to: contact, alert: alert)
        }
    }
    
    private func sendEmailNotification(to contact: CaregiverContact, alert: MedicationAlert) {
        // This would integrate with email service in production
        print("📧 Sending email to \(contact.email): \(alert.message)")
    }
    
    private func sendSMSNotification(to contact: CaregiverContact, alert: MedicationAlert) {
        // This would integrate with SMS service in production
        print("📱 Sending SMS to \(contact.phone): \(alert.message)")
    }
    
    func getAlertsForLast(days: Int) -> [MedicationAlert] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return alerts.filter { $0.timestamp >= cutoffDate }
    }
    
    func clearOldAlerts() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        alerts.removeAll { $0.timestamp < cutoffDate }
    }
    
    func getUnreadAlertsCount() -> Int {
        // In a real app, you'd track read/unread status
        return alerts.filter { alert in
            Calendar.current.isDateInToday(alert.timestamp)
        }.count
    }
}