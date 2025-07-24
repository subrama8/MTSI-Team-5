import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @EnvironmentObject private var log     : DropLog
    private let cal = Calendar.current

    private func status(for day: Date) -> Color {
        let expected = schedule.meds.reduce(0) {
            $0 + schedule.expectedDoses(for: $1, on: day)
        }
        let taken = log.events.filter { cal.isDate($0.date, inSameDayAs: day) }
                              .count
        if expected == 0        { return .gray.opacity(0.3) }
        if taken >= expected    { return .green.opacity(0.8) }
        if taken > 0            { return .yellow.opacity(0.8) }
        return .red.opacity(0.7)
    }

    private func makeSections() -> [(title: String, events: [DropEvent])] {
        let grouped = Dictionary(grouping: log.events) {
            cal.startOfDay(for: $0.date) }
        return grouped.map { day, events in
            let title = cal.isDateInToday(day) ? "Today"
                        : DateFormatter.localizedString(from: day,
                                                        dateStyle: .medium,
                                                        timeStyle: .none)
            return (title, events.sorted { $0.date > $1.date })
        }
        .sorted { $0.events.first!.date > $1.events.first!.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // 6-week heat-map calendar
                let days = (0..<42).map {
                    cal.date(byAdding: .day, value: -$0,
                             to: cal.startOfDay(for: .now))! }.reversed()
                LazyVGrid(columns: Array(repeating: .init(.flexible(minimum: 12)),
                                         count: 7), spacing: 4) {
                    ForEach(days, id: \.self) { d in
                        Circle()
                            .fill(status(for: d))
                            .frame(height: 12)
                            .overlay(
                                cal.isDateInToday(d)
                                ? Circle().stroke(Color.primary, lineWidth: 1)
                                : nil
                            )
                    }
                }
                .padding(.horizontal)

                // History cards
                ForEach(makeSections(), id: \.title) { sec in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(sec.title).font(.title3.bold())
                            .padding(.horizontal)
                        ForEach(sec.events) { HistoryCard(event: $0) }
                    }
                }

                if makeSections().isEmpty {
                    Text("No medication history yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("History")
    }
}

private struct HistoryCard: View {
    let event: DropEvent
    private let df: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f }()

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
        .clipShape(RoundedRectangle(cornerRadius: 16,
                                    style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .padding(.horizontal)
    }
}
