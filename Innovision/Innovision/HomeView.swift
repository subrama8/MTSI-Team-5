import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log: DropLog
    @EnvironmentObject private var device: DeviceService
    
    @State private var showLogSheet = false
    
    // Find the soonest upcoming dose
    private var nextDose: (med: Medication, date: Date)? {
        schedule.meds
            .compactMap { med in
                med.nextDose().map { (med, $0) }
            }
            .min { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            
            // ---- Streak ring ----
            Gauge(value: Double(log.streak), in: 0...30) {
                Text("Streak")
            } currentValueLabel: {
                Text("\(log.streak)d")
            }
            .gaugeStyle(.accessoryCircular)
            .frame(width: 120, height: 120)
            
            // ---- Next dose countdown ----
            if let upcoming = nextDose {
                VStack(spacing: 4) {
                    Text("Next dose in")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text(upcoming.date, style: .relative)
                        .font(.title3).bold()
                    Text(upcoming.med.name)
                        .padding(6)
                        .background(upcoming.med.color.opacity(0.2))
                        .cornerRadius(6)
                }
            } else {
                Text("No doses scheduled").foregroundColor(.secondary)
            }
            
            // ---- Start / Stop device ----
            Button {
                if device.isRunning {
                    device.stopDropper()
                } else {
                    if !device.isConnected { device.connect() }
                    device.startDropper()
                }
            } label: {
                Label(device.isRunning ? "Stop" : "Start",
                      systemImage: device.isRunning ? "pause.circle"
                                                    : "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            // ---- Manual log button ----
            Button {
                showLogSheet = true
            } label: {
                Label("Log a Drop", systemImage: "drop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showLogSheet) {
                ManualLogSheet()
            }
        }
        .padding()
        .navigationTitle("Home")
    }
}

// MARK: Manual log picker sheet ---------------------------------------------
private struct ManualLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log: DropLog
    @State private var selected: Medication?
    
    var body: some View {
        NavigationStack {
            List(schedule.meds) { med in
                HStack {
                    Circle().fill(med.color).frame(width: 12)
                    Text(med.name)
                    Spacer()
                    if selected?.id == med.id { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = med }
            }
            .navigationTitle("Which med?")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        if let med = selected { log.record(med, auto: false) }
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
