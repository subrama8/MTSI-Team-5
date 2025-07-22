import SwiftUI
import CoreData

struct MedicationLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MedicationLog.timestamp, ascending: false)],
        animation: .default
    ) private var logs: FetchedResults<MedicationLog>
    
    @State private var selectedPeriod = Period.week
    @State private var selectedFilter = LogFilter.all
    @State private var showingManualLogForm = false
    
    enum Period: String, CaseIterable {
        case week = "7"
        case twoWeeks = "14"
        case month = "30"
        case threeMonths = "90"
        
        var displayName: String {
            switch self {
            case .week: return "Last 7 days"
            case .twoWeeks: return "Last 14 days"
            case .month: return "Last 30 days"
            case .threeMonths: return "Last 90 days"
            }
        }
        
        var days: Int {
            return Int(rawValue) ?? 7
        }
    }
    
    enum LogFilter: String, CaseIterable {
        case all = "all"
        case automatic = "automatic"
        case scheduled = "scheduled"
        case manual = "manual"
        
        var displayName: String {
            switch self {
            case .all: return "All Entries"
            case .automatic: return "Device Assisted"
            case .scheduled: return "Scheduled"
            case .manual: return "Manual"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Controls
                controlsSection
                
                // Content
                if filteredLogs.isEmpty {
                    emptyStateView
                } else {
                    logsListView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingManualLogForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .accessibilityLabel("Add manual medication entry")
                }
            }
        }
        .sheet(isPresented: $showingManualLogForm) {
            ManualLogFormView()
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Stats cards
            statsCardsView
            
            // Filter controls
            CardView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Filters")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        // Time period picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Period")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Picker("Period", selection: $selectedPeriod) {
                                ForEach(Period.allCases, id: \.self) { period in
                                    Text(period.displayName)
                                        .tag(period)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        Spacer()
                        
                        // Filter picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Type")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(LogFilter.allCases, id: \.self) { filter in
                                    Text(filter.displayName)
                                        .tag(filter)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var statsCardsView: some View {
        HStack(spacing: 12) {
            StatCardView(
                title: "Total Doses",
                value: "\(filteredLogs.count)",
                color: Color("LightBlue")
            )
            
            StatCardView(
                title: "Device Assisted",
                value: "\(filteredLogs.filter { $0.deviceUsed }.count)",
                color: .green
            )
        }
    }
    
    private var logsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLogs, id: \.objectID) { log in
                    MedicationLogRowView(log: log)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            EmptyStateView(
                title: selectedFilter == .all ?
                    "No medication logs found" :
                    "No \(selectedFilter.displayName.lowercased()) logs found",
                message: selectedFilter == .all ?
                    "Start tracking your medication usage to see your history here" :
                    "Try adjusting your filters to see more entries",
                systemImage: "list.clipboard",
                actionTitle: selectedFilter != .all ? "Show All Logs" : "Add Manual Entry"
            ) {
                if selectedFilter != .all {
                    selectedFilter = .all
                } else {
                    showingManualLogForm = true
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var filteredLogs: [MedicationLog] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate
        
        return logs.filter { log in
            guard let timestamp = log.timestamp else { return false }
            
            // Date filter
            let isInDateRange = timestamp >= startDate && timestamp <= endDate
            
            // Type filter
            let matchesType: Bool
            switch selectedFilter {
            case .all:
                matchesType = true
            case .automatic:
                matchesType = log.type == "automatic"
            case .scheduled:
                matchesType = log.type == "scheduled"
            case .manual:
                matchesType = log.type == "manual"
            }
            
            return isInDateRange && matchesType
        }
    }
}

// MARK: - Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Medication Log Row
struct MedicationLogRowView: View {
    let log: MedicationLog
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        CardView {
            HStack(spacing: 12) {
                // Type icon
                typeIcon
                
                // Main content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.medicationName ?? "Unknown Medication")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Type badge
                        Text(typeLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.2))
                            .foregroundColor(typeColor)
                            .cornerRadius(8)
                        
                        if log.deviceUsed {
                            Image(systemName: "iphone")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if let dosage = log.dosage {
                        Text("Dosage: \(dosage)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatTimestamp(log.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let notes = log.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Delete button for manual entries
                if log.type == "manual" {
                    Button {
                        deleteLog()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .accessibilityLabel("Delete manual entry")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Medication log for \(log.medicationName ?? "unknown medication")")
    }
    
    private var typeIcon: some View {
        Image(systemName: typeSystemImage)
            .font(.title3)
            .foregroundColor(typeColor)
    }
    
    private var typeSystemImage: String {
        switch log.type {
        case "automatic":
            return "iphone"
        case "scheduled":
            return "calendar"
        case "manual":
            return "person"
        default:
            return "pill"
        }
    }
    
    private var typeLabel: String {
        switch log.type {
        case "automatic":
            return "Device"
        case "scheduled":
            return "Scheduled"
        case "manual":
            return "Manual"
        default:
            return "Unknown"
        }
    }
    
    private var typeColor: Color {
        switch log.type {
        case "automatic":
            return .green
        case "scheduled":
            return Color("LightBlue")
        case "manual":
            return .purple
        default:
            return .gray
        }
    }
    
    private func formatTimestamp(_ timestamp: Date?) -> String {
        guard let timestamp = timestamp else { return "Unknown time" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    private func deleteLog() {
        viewContext.delete(log)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete log: \(error)")
        }
    }
}

#Preview {
    PreviewWrapper {
        MedicationLogView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}