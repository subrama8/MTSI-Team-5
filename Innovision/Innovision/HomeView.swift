import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log     : DropLog
    @EnvironmentObject private var device  : DeviceService
    @EnvironmentObject private var conflictDetector: ConflictDetector

    @State private var showLogSheet  = false
    @State private var showConflicts = false

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {

                Image("innovisionlogo")
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .padding(.horizontal, 4)

                if conflictDetector.hasHighSeverityConflicts() {
                    Button { showConflicts = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("High-severity conflicts detected")
                                    .font(.headline)
                                Text("Tap to review details")
                                    .font(.caption).opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).opacity(0.8)
                        }
                        .padding().background(Color.red)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain).padding(.horizontal)
                }

                if schedule.meds.isEmpty {
                    Text("Add a medication to get started!")
                        .foregroundColor(.secondary)
                }

                ForEach(schedule.meds) { med in
                    let expected = schedule.expectedDoses(for: med)
                    let taken    = log.takenToday(for: med)
                    let progress = expected == 0 ? 0 :
                                   Double(taken) / Double(expected)
                    let done = expected > 0 && taken >= expected

                    VStack(spacing: 16) {
                        Text(med.name).font(.headline)
                        ProgressRing(progress: progress,
                                     baseColor: med.color,
                                     allDone: done)
                        Text("\(taken)/\(expected) logged today")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20,
                                                style: .continuous))
                    .shadow(color: .black.opacity(0.06),
                            radius: 4, y: 2)
                    .padding(.horizontal)
                }

                // Plotter connection status
                if !device.isConnected {
                    VStack(spacing: 12) {
                        Label("Plotter Disconnected", systemImage: "wifi.slash")
                            .foregroundColor(.orange)
                        Button("Connect to Plotter") {
                            device.connect()
                        }
                        .buttonStyle(BigButton())
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 16) {
                        // Connection status
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                            Text("Connected to Plotter")
                                .foregroundColor(.green)
                            Spacer()
                            Text(device.plotterStatus.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Start and Stop plotter buttons
                        HStack(spacing: 16) {
                            Button {
                                Task {
                                    await device.startPlotter()
                                }
                            } label: {
                                Label("Start Plotter", systemImage: "play.fill")
                            }
                            .buttonStyle(BigButton())
                            
                            Button {
                                Task {
                                    await device.stopPlotter()
                                }
                            } label: {
                                Label("Stop Plotter", systemImage: "stop.fill")
                            }
                            .buttonStyle(BigButton())
                        }
                        .padding(.horizontal)
                        
                        // Refresh status button
                        Button {
                            Task {
                                await device.getPlotterStatus()
                            }
                        } label: {
                            Label("Refresh Status", systemImage: "arrow.clockwise")
                        }
                        .font(.caption)
                        .padding(.horizontal)
                    }
                }
                
                // Show connection error if any
                if let error = device.connectionError {
                    Text("Connection Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Button { showLogSheet = true } label: {
                    Label("Log a Drop", systemImage: "plus")
                }
                .buttonStyle(BigButton()).padding(.horizontal)
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

    // Manual log sheet (unchanged from previous)
    private struct ManualLogSheet: View {
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var schedule: MedicationSchedule
        @EnvironmentObject private var log: DropLog
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
