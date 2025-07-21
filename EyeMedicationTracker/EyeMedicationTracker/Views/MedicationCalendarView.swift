import SwiftUI
import CoreData

struct MedicationCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var notificationManager: NotificationManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MedicationSchedule.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var activeSchedules: FetchedResults<MedicationSchedule>
    
    @State private var selectedDate = Date()
    @State private var showingScheduleForm = false
    @State private var editingSchedule: MedicationSchedule?
    @State private var showingUpcomingDoses = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Upcoming doses card
                    if showingUpcomingDoses {
                        upcomingDosesCard
                    }
                    
                    // Compliance stats
                    complianceStatsCard
                    
                    // Calendar
                    calendarCard
                    
                    // Active schedules
                    activeSchedulesCard
                }
                .padding()
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScheduleForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .accessibilityLabel("Add new medication schedule")
                }
            }
        }
        .sheet(isPresented: $showingScheduleForm) {
            MedicationScheduleFormView(schedule: editingSchedule)
                .onDisappear {
                    editingSchedule = nil
                    // Reschedule notifications after changes
                    notificationManager.scheduleUpcomingNotifications()
                }
        }
        .onAppear {
            notificationManager.scheduleUpcomingNotifications()
        }
        .refreshable {
            notificationManager.scheduleUpcomingNotifications()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Medication Schedule")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Plan and track your eye medication routine")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var upcomingDosesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderView(
                    "Upcoming Doses",
                    systemImage: "clock",
                    actionTitle: showingUpcomingDoses ? "Hide" : "Show"
                ) {
                    withAnimation(.easeInOut) {
                        showingUpcomingDoses.toggle()
                    }
                }
                
                if showingUpcomingDoses {
                    UpcomingDosesListView(limit: 3)
                }
            }
        }
    }
    
    private var complianceStatsCard: some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundColor(Color("LightBlue"))
                        
                        Text("30-Day Compliance")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ComplianceStatsView(days: 30)
                }
                
                Spacer()
            }
        }
    }
    
    private var calendarCard: some View {
        CardView {
            VStack(spacing: 16) {
                CalendarHeaderView(selectedDate: $selectedDate)
                
                CalendarGridView(
                    selectedDate: $selectedDate,
                    schedules: Array(activeSchedules)
                )
            }
        }
    }
    
    private var activeSchedulesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderView(
                    "Active Schedules",
                    systemImage: "pill",
                    actionTitle: "Add",
                    action: {
                        showingScheduleForm = true
                    }
                )
                
                if activeSchedules.isEmpty {
                    EmptyStateView(
                        title: "No medication schedules",
                        message: "Create your first medication schedule to get started with tracking",
                        systemImage: "calendar.badge.plus",
                        actionTitle: "Create Schedule"
                    ) {
                        showingScheduleForm = true
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(activeSchedules, id: \.objectID) { schedule in
                            MedicationScheduleRowView(schedule: schedule) {
                                editingSchedule = schedule
                                showingScheduleForm = true
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Doses List
struct UpcomingDosesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let limit: Int
    
    @FetchRequest private var upcomingSchedules: FetchedResults<MedicationSchedule>
    
    init(limit: Int = 5) {
        self.limit = limit
        self._upcomingSchedules = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \MedicationSchedule.createdAt, ascending: true)],
            predicate: NSPredicate(format: "isActive == YES")
        )
    }
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(upcomingDoses.prefix(limit), id: \.id) { dose in
                UpcomingDoseRowView(dose: dose)
            }
            
            if upcomingDoses.count > limit {
                Text("+\(upcomingDoses.count - limit) more doses scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private var upcomingDoses: [DoseInfo] {
        let now = Date()
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        
        return upcomingSchedules.compactMap { schedule in
            guard let nextDose = schedule.nextDose,
                  nextDose <= endDate else { return nil }
            
            let timeUntil = nextDose.timeIntervalSince(now)
            return DoseInfo(
                id: UUID(),
                schedule: schedule,
                doseTime: nextDose,
                timeUntilString: formatTimeUntil(timeUntil)
            )
        }
        .sorted { $0.doseTime < $1.doseTime }
    }
    
    private func formatTimeUntil(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        
        if minutes < 0 {
            return "Overdue"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if minutes < 1440 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else {
            let days = minutes / 1440
            return "\(days)d"
        }
    }
}

// MARK: - Supporting Types
struct DoseInfo: Identifiable {
    let id: UUID
    let schedule: MedicationSchedule
    let doseTime: Date
    let timeUntilString: String
}

// MARK: - Upcoming Dose Row
struct UpcomingDoseRowView: View {
    let dose: DoseInfo
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color(hex: dose.schedule.color ?? "#0ea5e9"))
                        .frame(width: 8, height: 8)
                    
                    Text(dose.schedule.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(dose.timeUntilString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            dose.timeUntilString == "Overdue" ?
                            Color.red.opacity(0.2) : Color("LightBlue").opacity(0.2)
                        )
                        .foregroundColor(
                            dose.timeUntilString == "Overdue" ? .red : Color("LightBlue")
                        )
                        .cornerRadius(8)
                }
                
                HStack {
                    Text("Dosage: \(dose.schedule.dosage ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Time: \(formatDoseTime(dose.doseTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                markDoseCompleted()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .accessibilityLabel("Mark dose as completed")
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatDoseTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func markDoseCompleted() {
        MedicationLog.createAutomaticLog(
            for: dose.schedule,
            deviceUsed: false,
            context: viewContext
        )
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save medication log: \(error)")
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PreviewWrapper {
        MedicationCalendarView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}