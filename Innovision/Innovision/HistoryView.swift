import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var log: DropLog
    private let cal = Calendar.current
    private let df: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()
    
    private var grouped: [(day: Date, events: [DropEvent])] {
        Dictionary(grouping: log.events) { cal.startOfDay(for: $0.date) }
            .map { (day: $0.key, events: $0.value) }
            .sorted { $0.day > $1.day }
    }
    
    var body: some View {
        List {
            ForEach(grouped, id: \.day) { section in
                Section(cal.isDateInToday(section.day) ? "Today"
                        : DateFormatter.localizedString(from: section.day,
                                                        dateStyle: .medium,
                                                        timeStyle: .none)) {
                    ForEach(section.events) { event in
                        HStack {
                            Circle().fill(event.med.color).frame(width: 10)
                            Text(event.med.name)
                            Spacer()
                            Text(df.string(from: event.date))
                            if event.auto { Image(systemName: "eye") }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .toolbar {
            Button { /* PDF export stub */ } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}
