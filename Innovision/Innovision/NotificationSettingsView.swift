import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationManager: LocalNotificationManager
    @EnvironmentObject private var caregiverService: CaregiverService
    
    @State private var showingAddCaregiver = false
    @State private var reminderOffset = 10 // minutes before dose
    @State private var enableMissedDoseAlerts = true
    @State private var enableCriticalAlerts = true
    @State private var enableCaregiverNotifications = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Push Notifications") {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text("Notification Permission")
                                .font(.headline)
                            Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                Task {
                                    try? await notificationManager.requestAuth()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    if let token = notificationManager.pushToken {
                        VStack(alignment: .leading) {
                            Text("Push Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(token.prefix(20)) + "...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Reminder Settings") {
                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Picker("Minutes Before", selection: $reminderOffset) {
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Group {
                        Toggle("10 minutes before dose", isOn: $notificationManager.notifyBefore)
                        Toggle("At dose time", isOn: $notificationManager.notifyAtTime)
                        Toggle("10 minutes after dose", isOn: $notificationManager.notifyAfter)
                    }
                    
                    Toggle("Missed Dose Alerts", isOn: $enableMissedDoseAlerts)
                    Toggle("Critical Alerts", isOn: $enableCriticalAlerts)
                }
                
                Section("Caregiver Notifications") {
                    Toggle("Enable Caregiver Alerts", isOn: $enableCaregiverNotifications)
                    
                    if enableCaregiverNotifications {
                        ForEach(caregiverService.caregivers, id: \.id) { caregiver in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(caregiver.name)
                                        .font(.headline)
                                    Text(caregiver.relationship)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if caregiver.isEmergencyContact {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        Button("Add Caregiver") {
                            showingAddCaregiver = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Recent Alerts") {
                    let recentAlerts = caregiverService.getAlertsForLast(days: 7)
                    
                    if recentAlerts.isEmpty {
                        Text("No recent alerts")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recentAlerts, id: \.id) { alert in
                            HStack {
                                Circle()
                                    .fill(alert.severity.color)
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading) {
                                    Text(alert.message)
                                        .font(.caption)
                                    Text(alert.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Test Notification") {
                        Task {
                            try? await notificationManager.schedule(
                                id: "test_notification",
                                at: Date().addingTimeInterval(5),
                                title: "Test Notification",
                                body: "This is a test notification from Innovision"
                            )
                        }
                    }
                    
                    Button("Clear All Notifications") {
                        notificationManager.cancelAllNotifications()
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Old Alerts") {
                        caregiverService.clearOldAlerts()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Notification Settings")
            .sheet(isPresented: $showingAddCaregiver) {
                AddCaregiverSheet()
            }
            .onChange(of: enableCaregiverNotifications) { isEnabled in
                caregiverService.isNotificationEnabled = isEnabled
            }
        }
    }
}

struct AddCaregiverSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var caregiverService: CaregiverService
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var relationship = "Family Member"
    @State private var isEmergencyContact = false
    
    let relationships = ["Family Member", "Friend", "Doctor", "Nurse", "Caregiver", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Relationship") {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { rel in
                            Text(rel).tag(rel)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Emergency Contact", isOn: $isEmergencyContact)
                }
            }
            .navigationTitle("Add Caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let caregiver = CaregiverContact(
                            name: name,
                            email: email,
                            phone: phone,
                            relationship: relationship,
                            isEmergencyContact: isEmergencyContact
                        )
                        caregiverService.addCaregiver(caregiver)
                        dismiss()
                    }
                    .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(LocalNotificationManager.shared)
        .environmentObject(CaregiverService())
}