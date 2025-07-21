import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var log: DropLog
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f
    }()
    var body: some View {
        List(log.events) { event in
            HStack {
                Image(systemName: event.autoDetected ? "eye" : "hand.thumbsup")
                VStack(alignment: .leading) {
                    Text(event.medName).font(.headline)
                    Text(df.string(from: event.date)).font(.caption)
                }
            }
        }
        .navigationTitle("History")
    }
} 