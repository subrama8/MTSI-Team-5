import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var log: DropLog
    private let cal = Calendar.current
    private let df: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    /// Pre‑group and sort so the body stays lightweight
    private var dailySections: [(title: String, events: [DropEvent])] {
        guard !log.events.isEmpty else { return [] }
        
        let grouped = Dictionary(grouping: log.events) { cal.startOfDay(for: $0.date) }

        return grouped.map { day, evts in
            let title = cal.isDateInToday(day)
                       ? "Today"
                       : DateFormatter.localizedString(from: day,
                                                       dateStyle: .medium,
                                                       timeStyle: .none)
            return (title, evts.sorted { $0.date > $1.date })
        }
        .sorted { $0.events.first?.date ?? Date.distantPast > $1.events.first?.date ?? Date.distantPast }
    }

    var body: some View {
        List {
            if dailySections.isEmpty {
                Section {
                    Text("No medication history yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(dailySections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.events) { event in
                            HistoryRow(event: event)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
    }

    // MARK: Row view
    private struct HistoryRow: View {
        let event: DropEvent
        private let df: DateFormatter = {
            let f = DateFormatter(); f.timeStyle = .short; return f
        }()

        var body: some View {
            HStack(spacing: 12) {
                Circle().fill(event.med.color).frame(width: 14)
                Text(event.med.name)
                Spacer()
                Text(df.string(from: event.date))
            }
            .padding(.vertical, 2)
        }
    }
}
