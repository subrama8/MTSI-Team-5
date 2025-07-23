import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var log: DropLog
    private let cal = Calendar.current

    private var sections: [(title: String, events: [DropEvent])] {
        let grouped = Dictionary(grouping: log.events) { cal.startOfDay(for: $0.date) }
        return grouped.map { day, evts in
            let title = cal.isDateInToday(day)
                       ? "Today"
                       : DateFormatter.localizedString(from: day,
                                                       dateStyle: .medium,
                                                       timeStyle: .none)
            return (title, evts.sorted { $0.date > $1.date })
        }
        .sorted { $0.events.first!.date > $1.events.first!.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                if sections.isEmpty {
                    Text("No medication history yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 120)
                }

                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section.title)
                            .font(.title3.bold())
                            .padding(.horizontal)

                        ForEach(section.events) { event in
                            HistoryCard(event: event)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("History")
    }
}

// Card‑style row
private struct HistoryCard: View {
    let event: DropEvent
    private let df: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(event.med.color).frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.med.name).font(.headline)
                Text(df.string(from: event.date))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .padding(.horizontal)
    }
}
