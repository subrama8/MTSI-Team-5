import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    
    var body: some View {
        List {
            ForEach(schedule.meds) { med in
                VStack(alignment: .leading) {
                    Text(med.name).font(.headline)
                    Text(med.times.map {
                        String(format: "%02d:%02d", $0.hour ?? 0, $0.minute ?? 0)
                    }.joined(separator: ", "))
                    .foregroundColor(.secondary)
                }
            }
            .onDelete { idx in schedule.meds.remove(atOffsets: idx) }
        }
        .navigationTitle("Medications")
    }
} 