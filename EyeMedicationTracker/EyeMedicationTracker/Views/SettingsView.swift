import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var arduinoService: ArduinoService
    
    @AppStorage("reminderSound") private var reminderSound = true
    @AppStorage("largeText") private var largeText = false
    @State private var showingClearDataAlert = false
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // Notifications Section
                Section {
                    notificationsSection
                } header: {
                    SectionHeader(title: "Notifications", icon: "bell")
                }
                
                // Accessibility Section
                Section {
                    accessibilitySection
                } header: {
                    SectionHeader(title: "Accessibility", icon: "accessibility")
                }
                
                // Data Management Section
                Section {
                    dataManagementSection
                } header: {
                    SectionHeader(title: "Data", icon: "externaldrive")
                }
                
                // About Section
                Section {
                    aboutSection
                } header: {
                    SectionHeader(title: "About", icon: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Data", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your medication schedules, logs, and settings. This action cannot be undone.")
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView()
        }
    }
    
    private var notificationsSection: some View {
        Group {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color("LightBlue"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Push Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Get reminders for upcoming medication doses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !notificationManager.isAuthorized {
                        Text("Tap to enable notifications")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if notificationManager.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Enable") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !notificationManager.isAuthorized {
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }
            }
            
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(Color("LightBlue"))
                    .frame(width: 24)
                
                Text("Reminder Sound")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("", isOn: $reminderSound)
                    .labelsHidden()
            }
            
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(Color("LightBlue"))
                    .frame(width: 24)
                
                Text("Test Notifications")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Test") {
                    notificationManager.sendTestNotification()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!notificationManager.isAuthorized)
            }
        }
    }
    
    private var accessibilitySection: some View {
        Group {
            HStack {
                Image(systemName: "textformat.size.larger")
                    .foregroundColor(Color("LightBlue"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large Text")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Use larger text throughout the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $largeText)
                    .labelsHidden()
            }
            
            NavigationLink {
                VoiceOverGuideView()
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(Color("LightBlue"))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VoiceOver Guide")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Learn how to use the app with VoiceOver")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Group {
            HStack {
                Image(systemName: "externaldrive.badge.plus")
                    .foregroundColor(Color("LightBlue"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Export your medication data for backup or sharing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Export") {
                    showingExportSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingExportSheet = true
            }
            
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Data is stored locally on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button {
                showingClearDataAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Clear All Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(Color("LightBlue"))
                        .frame(width: 24)
                    
                    Text("Eye Care Tracker")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Built for managing eye medication schedules with device integration")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Your data is stored locally on your device and is never transmitted to external servers. No personal information is collected or shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func clearAllData() {
        // Clear Core Data
        let context = PersistenceController.shared.container.viewContext
        
        // Delete all entities
        let entities = ["MedicationSchedule", "MedicationLog", "ScheduledDose"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }
        
        // Clear UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "arduino_ip")
        userDefaults.removeObject(forKey: "reminderSound")
        userDefaults.removeObject(forKey: "largeText")
        
        // Disconnect Arduino
        arduinoService.disconnect()
        
        // Clear notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Reset notification manager
        notificationManager.isAuthorized = false
        
        print("All data cleared successfully")
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color("LightBlue"))
            Text(title)
                .textCase(.none)
        }
    }
}

// MARK: - VoiceOver Guide View
struct VoiceOverGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Using Eye Care Tracker with VoiceOver")
                    .font(.title2)
                    .fontWeight(.bold)
                
                GuideSection(
                    title: "Navigation",
                    content: "Swipe right to move to the next element, swipe left to go back. The app has four main tabs: Device, Schedule, History, and Settings."
                )
                
                GuideSection(
                    title: "Device Control",
                    content: "The main toggle button is labeled 'Start eye tracking plotter' or 'Stop eye tracking plotter'. Double-tap to activate or deactivate the device."
                )
                
                GuideSection(
                    title: "Adding Medications",
                    content: "In the Schedule tab, use the 'Add new medication schedule' button to create medication reminders. Fill out the form using the standard iOS text input gestures."
                )
                
                GuideSection(
                    title: "Calendar Navigation",
                    content: "The calendar shows your medication schedule. Each day announces the number of doses scheduled and completed."
                )
                
                GuideSection(
                    title: "Notifications",
                    content: "You'll receive spoken notifications for medication reminders. You can mark doses complete or snooze them directly from the notification."
                )
            }
            .padding()
        }
        .navigationTitle("VoiceOver Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
    }
}

// MARK: - Export Data View
struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(Color("LightBlue"))
                
                VStack(spacing: 12) {
                    Text("Export Your Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Export your medication schedules and logs as a JSON file that you can save or share with healthcare providers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportData() {
        // Implementation would create and share JSON export
        // For now, just dismiss
        dismiss()
    }
}

#Preview {
    PreviewWrapper {
        SettingsView()
    }
}