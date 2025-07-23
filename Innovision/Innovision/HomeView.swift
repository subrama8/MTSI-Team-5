import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log:       DropLog
    @EnvironmentObject private var device:    DeviceService
    @EnvironmentObject private var conflictDetector: ConflictDetector

    @State private var showLogSheet  = false
    @State private var showConflicts = false

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {

                // ──  FULL‑WIDTH INNOVISION BANNER  ───────────────────────
                Image("innovisionlogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)        // ⬅️  super‑sized banner
                    .padding(.horizontal, 4)

                // ──  CONFLICT BANNER  ────────────────────────────────────
                if conflictDetector.hasHighSeverityConflicts() {
                    Button { showConflicts = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("High‑severity conflicts detected")
                                    .font(.headline)
                                Text("Tap to review details")
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        .padding()
                        .background(Color.red)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                // ──  MEDICATION PROGRESS CARDS  ─────────────────────────
                if schedule.meds.isEmpty {
                    Text("Add a medication to get started!")
                        .foregroundColor(.secondary)
                }

                ForEach(schedule.meds) { med in
                    let expected  = schedule.expectedDoses(for: med)
                    let taken     = log.takenToday(for: med)
                    let progress  = expected == 0 ? 0 : Double(taken) / Double(expected)
                    let allDone   = expected > 0 && taken >= expected

                    VStack(spacing: 16) {
                        Text(med.name).font(.headline)

                        ProgressRing(progress: progress,
                                     baseColor: med.color,
                                     allDone: allDone)

                        Text("\(taken)/\(expected) logged today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    .padding(.horizontal)
                }

                // ──  DEVICE TOGGLE  ────────────────────────────────────
                Toggle(isOn: $device.isRunning) {
                    Label(device.isRunning ? "Running" : "Off",
                          systemImage: device.isRunning ? "drop.fill" : "pause.circle")
                        .font(.headline)
                }
                .toggleStyle(.button)
                .tint(.brandPrimary)
                .padding(.horizontal)
                .onChange(of: device.isRunning) { newVal in
                    if newVal {
                        if !device.isConnected { device.connect() }
                        device.startDropper()
                    } else {
                        device.stopDropper()
                    }
                }

                // ──  MANUAL‑LOG BUTTON  ────────────────────────────────
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log a Drop", systemImage: "plus")
                }
                .buttonStyle(BigButton())
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(
            LinearGradient(colors: [.brandPrimary.opacity(0.10), .back],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle("Home")
        .sheet(isPresented: $showLogSheet)  { ManualLogSheet() }
        .sheet(isPresented: $showConflicts) { ConflictsView() }
    }

    //──────────────────────────────────────────────────────────
    // MARK: Manual log sheet (MUST be in the build target)
    //──────────────────────────────────────────────────────────
    private struct ManualLogSheet: View {
        @Environment(\.dismiss)          private var dismiss
        @EnvironmentObject private var schedule: MedicationSchedule
        @EnvironmentObject private var log:       DropLog
        @State private var selected: Medication?

        var body: some View {
            NavigationView {
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

}

// ── ManualLogSheet remains unchanged, keep it in this file or in its own file.
