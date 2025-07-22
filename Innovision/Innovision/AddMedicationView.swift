import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var schedule: MedicationSchedule

    @ObservedObject private var med: Medication
    @State private var newTime   = Date()
    @State private var freqStyle: Frequency
    private let isNew: Bool

    // MARK: init --------------------------------------------------------------
    init(existing: Medication? = nil) {
        if let m = existing {
            _med       = ObservedObject(wrappedValue: m)
            _freqStyle = State(initialValue: m.frequency)
            isNew      = false
        } else {
            let blank  = Medication(name: "", color: .blue)
            _med       = ObservedObject(wrappedValue: blank)
            _freqStyle = State(initialValue: .daily)
            isNew      = true
        }
    }

    // MARK: body --------------------------------------------------------------
    var body: some View {
        NavigationStack {
            Form {
                basicSection
                timesSection
                frequencySection
            }
            .navigationTitle(isNew ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        med.frequency = freqStyle
                        if isNew { Task { await schedule.add(med) } }
                        dismiss()
                    }
                    .disabled(med.name.trimmingCharacters(in: .whitespaces).isEmpty
                              || med.times.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    // MARK: sections ----------------------------------------------------------
    private var basicSection: some View {
        Section("Name & Color") {
            TextField("Medication name", text: $med.name)
            ColorPicker("Label color", selection: $med.color, supportsOpacity: false)
        }
    }

    private var timesSection: some View {
        Section("Dose Times  (\(med.times.count)/day)") {
            ForEach(med.times.indices, id: \.self) { i in
                DatePicker("",
                           selection: Binding(
                               get: { Self.date(from: med.times[i]) },
                               set: { med.times[i] = Self.comps(from: $0) }),
                           displayedComponents: .hourAndMinute)
                .labelsHidden()
            }

            DatePicker("Select time", selection: $newTime,
                       displayedComponents: .hourAndMinute)
            Button("➕ Add time") { med.times.append(Self.comps(from: newTime)) }
        }
    }

    private var frequencySection: some View {
        Section("Reminder pattern") {
            Picker("How often?", selection: $freqStyle) {
                Text("Daily").tag(Frequency.daily)
                Text("Weekly").tag(Frequency.weekly([]))
            }
            .pickerStyle(.segmented)

            if case .weekly(let set) = freqStyle {
                WeekdayPicker(initial: set) { freqStyle = .weekly($0) }
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: – Weekday picker (owns its own State) -----------------------------
    private struct WeekdayPicker: View {
        @State private var selection: Set<Int>
        let onChange: (Set<Int>) -> Void

        private let syms = DateFormatter().veryShortWeekdaySymbols ??
                           ["S","M","T","W","T","F","S"]
        private let days = [1,2,3,4,5,6,7]

        init(initial: Set<Int>, onChange: @escaping (Set<Int>) -> Void) {
            _selection = State(initialValue: initial)
            self.onChange = onChange
        }

        var body: some View {
            HStack {
                ForEach(days, id: \.self) { day in
                    let isSel = selection.contains(day)
                    Text(syms[day - 1])
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(isSel ? Color.blue.opacity(0.25)
                                          : Color(.systemGray5))
                        .cornerRadius(8)
                        .onTapGesture {
                            if isSel { selection.remove(day) }
                            else     { selection.insert(day) }
                            onChange(selection)
                        }
                }
            }
        }
    }

    // MARK: helpers -----------------------------------------------------------
    private static func comps(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
    private static func date(from comps: DateComponents) -> Date {
        Calendar.current.date(from: comps) ?? .now
    }
}
