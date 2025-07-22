import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log: DropLog
    @EnvironmentObject private var device: DeviceService
    @State private var showLogSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ——— Rings ———
                if schedule.meds.isEmpty {
                    Text("Add a medication to get started!")
                        .foregroundStyle(.secondary)
                }

                ForEach(schedule.meds) { med in
                    let expected = schedule.expectedDoses(for: med)
                    let taken    = log.takenToday(for: med)
                    let progress = expected == 0 ? 0 : Double(taken) / Double(expected)
                    let filled   = expected > 0 && taken >= expected

                    VStack(spacing: 4) {
                        Text(med.name).font(.headline)
                        ProgressRing(progress: progress,
                                     baseColor: med.color,
                                     allDone: filled)
                        Text("\(taken)/\(expected) logged today")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                }

                // ——— Device toggle ———
                Toggle(isOn: $device.isRunning) {
                    Label(device.isRunning ? "Running" : "Off",
                          systemImage: device.isRunning ? "drop.fill"
                                                        : "pause.circle")
                }
                .toggleStyle(.button)
                .tint(.skyBlue)
                .onChange(of: device.isRunning) { _, newVal in   // iOS 17 syntax
                    if newVal {
                        if !device.isConnected { device.connect() }
                        device.startDropper()
                    } else {
                        device.stopDropper()
                    }
                }

                // ——— Manual log button ———
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log a Drop", systemImage: "plus")
                }
                .buttonStyle(BigButton())
            }
            .padding()
        }
        .navigationTitle("Home")
        .sheet(isPresented: $showLogSheet) { ManualLogSheet() }
    }
}

// MARK: – Manual drop logger (kept in same file so it's always in scope)
private struct ManualLogSheet: View {
    @Environment(\.dismiss)          private var dismiss
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log: DropLog
    @State private var selected: Medication?

    var body: some View {
        NavigationStack {
            List(schedule.meds) { med in
                HStack {
                    Circle().fill(med.color).frame(width: 16)
                    Text(med.name)
                    Spacer()
                    if selected?.id == med.id { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = med }
            }
            .navigationTitle("Select Medication")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        if let m = selected { log.record(m, auto: false) }
                        dismiss()
                    }
                    .disabled(selected == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
