import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @State private var showAdd = false
    @State private var editMed: Medication?

    var body: some View {
        List {
            ForEach(schedule.meds) { med in
                MedicationRow(med: med)
                    .swipeActions {
                        Button("Edit") { editMed = med }
                            .tint(.blue)

                        Button(role: .destructive) {
                            schedule.meds.removeAll { $0.id == med.id }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Medications")
        .toolbar {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAdd) { AddMedicationView() }
        .sheet(item: $editMed)       { AddMedicationView(existing: $0) }
    }

    // MARK: Row ---------------------------------------------------------------
    private struct MedicationRow: View {
        @ObservedObject var med: Medication
        private let df: DateFormatter = {
            let f = DateFormatter(); f.timeStyle = .short; return f
        }()

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(med.color).frame(width: 10)
                    Text(med.name).font(.headline)
                }
                Text(
                    med.times
                        .compactMap { Calendar.current.date(from: $0) }
                        .map(df.string(from:))
                        .joined(separator: ", ")
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}
