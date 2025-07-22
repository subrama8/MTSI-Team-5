import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @State private var showAdd = false
    @State private var editMed: Medication?

    var body: some View {
        List {
            ForEach(schedule.meds) { med in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(med.color).frame(width: 14)
                        Text(med.name).font(.title3.bold())
                        Spacer()
                        Text("\(med.times.count)×/day").foregroundStyle(.secondary)
                    }
                    Text(med.frequency.description).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button("Edit") { editMed = med }.tint(.blue)
                    Button(role: .destructive) {
                        schedule.meds.removeAll { $0.id == med.id }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Schedule")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) { AddMedicationView() }
        .sheet(item: $editMed)       { AddMedicationView(existing: $0) }
    }
}
