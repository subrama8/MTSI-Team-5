import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var schedule: MedicationSchedule
    @State private var showAdd = false
    @State private var editMed: Medication?

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    /// Human‑readable dose summary, e.g. “3× / day” or “2× / week”
    private func summary(for med: Medication) -> String {
        switch med.frequency {
        case .daily:
            return "\(med.times.count)× / day"
        case .weekly(let days):
            return "\(med.times.count)× / week (\(days.count) days)"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(schedule.meds) { med in
                    VStack(alignment: .leading, spacing: 16) {

                        //--------------------------------------------------
                        // Name + colour + summary line
                        //--------------------------------------------------
                        HStack {
                            Circle().fill(med.color).frame(width: 14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(med.name).font(.title3.bold())
                                Text(summary(for: med))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(med.frequency.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        //--------------------------------------------------
                        // Times as little pills
                        //--------------------------------------------------
                        FlowLayout(alignment: .leading, spacing: 8) {
                            ForEach(med.times.indices, id: \.self) { idx in
                                let date = Calendar.current.date(from: med.times[idx]) ?? .now
                                Text(timeFmt.string(from: date))
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .contextMenu {
                        Button("Edit")   { editMed = med }
                        Button("Delete", role: .destructive) {
                            Task { await schedule.removeMedication(med) }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Schedule")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) { AddMedicationView() }
        .sheet(item: $editMed)       { AddMedicationView(existing: $0) }
    }
}

// FlowLayout helper stays identical
private struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: Content
    init(alignment: HorizontalAlignment,
         spacing: CGFloat,
         @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo.size)
        }
    }
    private func generate(in size: CGSize) -> some View {
        var x: CGFloat = 0, y: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content
                .alignmentGuide(.leading) { d in
                    if x + d.width > size.width { x = 0; y -= d.height + spacing }
                    defer { if d.width < size.width { x += d.width + spacing } }
                    return x
                }
                .alignmentGuide(.top) { _ in y }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }
}
