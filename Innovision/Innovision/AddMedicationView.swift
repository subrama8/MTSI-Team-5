import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var schedule: MedicationSchedule

    @ObservedObject private var med: Medication
    @State private var newTime   = Date()
    @State private var freqStyle : Frequency
    private let isNew: Bool

    // MARK: – Init
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

    // MARK: – UI
    var body: some View {
        NavigationView {
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
                        if isNew {
                            Task { await schedule.add(med) }
                        } else {
                            Task { await schedule.updateMedication(med) }
                        }
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

    // MARK: – Sections
    private var basicSection: some View {
        Section("Name & Color") {
            TextField("Medication name", text: $med.name)
            ColorPicker("Label color",
                        selection: $med.color,
                        supportsOpacity: false)
        }
    }

    private var timesSection: some View {
        Section("Dose Times  (\(med.times.count)/day)") {
            HStack {
                DatePicker("New time",
                           selection: $newTime,
                           displayedComponents: .hourAndMinute)
                Button("Add") {
                    med.times.append(Self.comps(from: newTime))
                }
                .buttonStyle(.borderedProminent)
            }
            if med.times.isEmpty {
                Text("No dose times added yet")
                    .foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(med.times.indices, id: \.self) { i in
                    HStack {
                        DatePicker("Time \(i + 1)",
                                   selection: Binding(
                                    get: { Self.date(from: med.times[i]) },
                                    set: { med.times[i] = Self.comps(from: $0) }),
                                   displayedComponents: .hourAndMinute)
                        Button("Remove") {
                            med.times.remove(at: i)
                        }
                        .foregroundColor(.red)
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: deleteTimes)
            }
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

    // MARK: – Helpers
    private func deleteTimes(offsets: IndexSet) {
        med.times.remove(atOffsets: offsets)
    }
    private static func comps(from d: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: d)
    }
    private static func date(from c: DateComponents) -> Date {
        Calendar.current.date(from: c) ?? .now
    }

    // MARK: – Inner weekday picker
    private struct WeekdayPicker: View {
        @State private var selection: Set<Int>
        let onChange: (Set<Int>) -> Void
        private let syms = DateFormatter().veryShortWeekdaySymbols ?? []
        private let days = [1,2,3,4,5,6,7]

        init(initial: Set<Int>, onChange: @escaping (Set<Int>) -> Void) {
            _selection = State(initialValue: initial)
            self.onChange = onChange
        }

        var body: some View {
            HStack {
                ForEach(days, id: \.self) { d in
                    let sel = selection.contains(d)
                    Text(syms[d - 1])
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(sel ? Color.blue.opacity(0.25)
                                         : Color(.systemGray5))
                        .cornerRadius(8)
                        .onTapGesture {
                            if sel { selection.remove(d) }
                            else   { selection.insert(d) }
                            onChange(selection)
                        }
                }
            }
        }
    }
}
