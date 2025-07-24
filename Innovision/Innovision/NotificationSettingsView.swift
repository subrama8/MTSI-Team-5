import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationManager: LocalNotificationManager
    @EnvironmentObject private var caregiverService  : CaregiverService

    @State private var showingAddCaregiver = false
    @State private var enableMissedDoseAlerts       = true
    @State private var enableCriticalAlerts         = true
    @State private var enableCaregiverNotifications = false

    var body: some View {
        NavigationView {
            Form {

                // MARK: – Permission
                Section("Push Notifications") {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized
                                            ? "checkmark.circle.fill"
                                            : "xmark.circle.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        VStack(alignment: .leading) {
                            Text("Notification Permission").font(.headline)
                            Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                Task { try? await notificationManager.requestAuth() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    if let token = notificationManager.pushToken {
                        VStack(alignment: .leading) {
                            Text("Push Token").font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(token.prefix(20)) + "…")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: – Reminder settings
                Section("Reminder Settings") {
                    HStack {
                        Text("Reminder Lead Time")
                        Spacer()
                        Picker("Minutes Before",
                               selection: $notificationManager.reminderLeadTime) {
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("\(notificationManager.reminderLeadTime) min before dose",
                           isOn: $notificationManager.notifyBefore)
                    Toggle("At dose time", isOn: $notificationManager.notifyAtTime)
                    Toggle("\(notificationManager.reminderLeadTime) min after dose",
                           isOn: $notificationManager.notifyAfter)

                    Toggle("Missed Dose Alerts", isOn: $enableMissedDoseAlerts)
                    Toggle("Critical Alerts",     isOn: $enableCriticalAlerts)
                }

                // MARK: – Caregiver alerts
                Section("Caregiver Notifications") {
                    Toggle("Enable Caregiver Alerts",
                           isOn: $enableCaregiverNotifications)
                    if enableCaregiverNotifications {
                        ForEach(caregiverService.caregivers, id: \.id) { cg in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cg.name).font(.headline)
                                    Text(cg.relationship)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if cg.isEmergencyContact {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        Button("Add Caregiver") { showingAddCaregiver = true }
                            .foregroundColor(.blue)
                    }
                }

                // MARK: – Recent alerts
                Section("Recent Alerts") {
                    let recent = caregiverService.getAlertsForLast(days: 7)
                    if recent.isEmpty {
                        Text("No recent alerts").foregroundColor(.secondary)
                    } else {
                        ForEach(recent, id: \.id) { alert in
                            HStack {
                                Circle().fill(alert.severity.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading) {
                                    Text(alert.message).font(.caption)
                                    Text(alert.timestamp, style: .relative)
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // MARK: – Actions
                Section("Actions") {
                    Button("Test Notification") {
                        Task {
                            try? await notificationManager.schedule(
                                id: UUID().uuidString,
                                at: Date().addingTimeInterval(1),
                                title: "Test Notification",
                                body: "If you see this, notifications work 🎉")
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
            .sheet(isPresented: $showingAddCaregiver) { AddCaregiverSheet() }
            .onChange(of: enableCaregiverNotifications) {
                caregiverService.isNotificationEnabled = $0
            }
        }
    }
}
