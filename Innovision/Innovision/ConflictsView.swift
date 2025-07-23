import SwiftUI

struct ConflictsView: View {
    @EnvironmentObject private var conflictDetector: ConflictDetector
    @EnvironmentObject private var schedule: MedicationSchedule
    
    var body: some View {
        NavigationView {
            List {
                if conflictDetector.conflicts.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("No Conflicts Detected")
                                .font(.headline)
                            
                            Text("Your current medications appear to be safe to use together.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section("Medication Conflicts") {
                        ForEach(conflictDetector.conflicts, id: \.medication1.id) { conflict in
                            ConflictRow(conflict: conflict)
                        }
                    }
                    
                    Section("Summary") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Conflicts:")
                                Spacer()
                                Text("\(conflictDetector.conflicts.count)")
                                    .fontWeight(.bold)
                            }
                            
                            ForEach([MedicationConflict.Severity.severe, .high, .moderate, .low], id: \.self) { severity in
                                let count = conflictDetector.conflictCount(for: severity)
                                if count > 0 {
                                    HStack {
                                        Circle()
                                            .fill(severity.color)
                                            .frame(width: 12, height: 12)
                                        Text(severityText(severity))
                                        Spacer()
                                        Text("\(count)")
                                    }
                                }
                            }
                        }
                    }
                    
                    if conflictDetector.hasHighSeverityConflicts() {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("High Severity Conflicts Detected")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                
                                Text("Please consult with your healthcare provider about these medication conflicts immediately.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Medication Conflicts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        conflictDetector.checkConflicts(for: schedule.meds)
                    }
                }
            }
        }
    }
    
    private func severityText(_ severity: MedicationConflict.Severity) -> String {
        switch severity {
        case .low: return "Low"
        case .moderate: return "Moderate" 
        case .high: return "High"
        case .severe: return "Severe"
        }
    }
}

struct ConflictRow: View {
    let conflict: MedicationConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(conflict.severity.color)
                    .frame(width: 12, height: 12)
                
                Text("\(conflict.medication1.name) + \(conflict.medication2.name)")
                    .font(.headline)
                
                Spacer()
                
                Text(conflictTypeText(conflict.conflictType))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(conflict.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
    
    private func conflictTypeText(_ type: MedicationConflict.ConflictType) -> String {
        switch type {
        case .interaction: return "Interaction"
        case .timing: return "Timing"
        case .dosage: return "Dosage"
        }
    }
}

#Preview {
    ConflictsView()
        .environmentObject(ConflictDetector())
        .environmentObject(MedicationSchedule())
}