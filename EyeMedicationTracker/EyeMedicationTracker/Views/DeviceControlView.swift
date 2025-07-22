import SwiftUI
import AVFoundation

struct DeviceControlView: View {
    @EnvironmentObject var arduinoService: ArduinoService
    @State private var showingDeviceDiscovery = false
    @State private var showingEyeTracking = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Connection Status Card
                    connectionStatusCard
                    
                    // Main Control Card
                    if arduinoService.isConnected {
                        mainControlCard
                    }
                    
                    // Error Display
                    if let errorMessage = errorMessage {
                        errorCard(message: errorMessage)
                    }
                    
                    // Success Message
                    if arduinoService.isConnected && errorMessage == nil {
                        successCard
                    }
                }
                .padding()
            }
            .navigationTitle("Device Control")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshDeviceStatus()
            }
        }
        .sheet(isPresented: $showingDeviceDiscovery) {
            DeviceDiscoveryView()
        }
        .sheet(isPresented: $showingEyeTracking) {
            EyeTrackingView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .onAppear {
            Task {
                await refreshDeviceStatus()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Device Control Screen")
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Device Control")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Connect and control your eye tracking device")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var connectionStatusCard: some View {
        CardView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "wifi")
                        .font(.title2)
                        .foregroundColor(Color("LightBlue"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection Status")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(arduinoService.isConnected ? .green : .red)
                                .frame(width: 12, height: 12)
                            
                            Text(arduinoService.isConnected ? "Connected" : "Disconnected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if arduinoService.isConnected {
                        Button("Disconnect") {
                            arduinoService.disconnect()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .font(.caption)
                    }
                }
                
                // Device Info
                if let deviceInfo = arduinoService.deviceInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        InfoRow(label: "Name", value: deviceInfo.name)
                        InfoRow(label: "IP Address", value: deviceInfo.ipAddress)
                        InfoRow(label: "Status", value: deviceInfo.isOnline ? "Online" : "Offline")
                    }
                    .padding()
                    .background(Color("LightBlue").opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Connection Actions
                if !arduinoService.isConnected {
                    Button(action: {
                        showingDeviceDiscovery = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(isLoading ? "Searching..." : "Find Device")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Device Connection Status")
    }
    
    private var mainControlCard: some View {
        CardView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Eye Tracker Control")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Start or stop the eye tracking plotter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Large Toggle Button
                Button(action: togglePlotter) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(arduinoService.plotterEnabled ? Color("LightBlue") : Color.gray.opacity(0.3))
                            .frame(width: 120, height: 60)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 50, height: 50)
                            .offset(x: arduinoService.plotterEnabled ? 25 : -25)
                            .shadow(radius: 2)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: arduinoService.plotterEnabled)
                }
                .disabled(isLoading)
                .accessibilityLabel(arduinoService.plotterEnabled ? "Stop eye tracking plotter" : "Start eye tracking plotter")
                .accessibilityHint("Double tap to toggle the plotter")
                .accessibilityAddTraits(.isButton)
                
                // Status Text
                VStack(spacing: 8) {
                    Text(arduinoService.plotterEnabled ? "Plotter Active" : "Plotter Inactive")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(arduinoService.plotterEnabled ?
                         "Eye tracking is active and logging medication usage" :
                         "Tap the switch above to start eye tracking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Eye Tracking Interface
                if arduinoService.plotterEnabled {
                    Button(action: {
                        showingEyeTracking = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Show Eye Tracking View")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Eye Tracker Control Panel")
    }
    
    private func errorCard(message: String) -> some View {
        CardView {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .background(Color.red.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var successCard: some View {
        CardView {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Connected")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your eye tracking device is ready to use")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .background(Color.green.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func togglePlotter() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if arduinoService.plotterEnabled {
                    try await arduinoService.stopPlotter()
                } else {
                    try await arduinoService.startPlotter()
                    
                    // Log medication usage when plotter is started
                    await logMedicationUsage()
                }
                
                await MainActor.run {
                    isLoading = false
                }
                
                // Refresh status
                await refreshDeviceStatus()
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func refreshDeviceStatus() async {
        do {
            try await arduinoService.refreshStatus()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func logMedicationUsage() async {
        // This would integrate with Core Data to log usage
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            
            // Create automatic usage log
            let log = MedicationLog(context: context)
            log.id = UUID()
            log.timestamp = Date()
            log.type = "automatic"
            log.medicationName = "Eye Tracker Session"
            log.deviceUsed = true
            log.notes = "Eye tracker plotter activated"
            log.createdAt = Date()
            
            PersistenceController.shared.save()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    DeviceControlView()
        .environmentObject(ArduinoService.shared)
}