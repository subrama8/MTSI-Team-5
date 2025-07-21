import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var schedule: MedicationSchedule
    
    @ObservedObject var med: Medication
    @State private var newTime   = Date()
    @State private var freqStyle: Frequency
    private let isNew: Bool
    
    // MARK: init --------------------------------------------------------------
    init(existing: Medication? = nil) {
        if let existing {
            _med       = ObservedObject(wrappedValue: existing)
            _freqStyle = State(initialValue: existing.frequency)
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
                basicsSection
                frequencySection
                timeSection
            }
            .navigationTitle(isNew ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        med.frequency = freqStyle
                        Task { await schedule.add(med) }
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
    private var basicsSection: some View {
        Section("Basics") {
            TextField("Name", text: $med.name)
            ColorPicker("Color", selection: $med.color, supportsOpacity: false)
        }
    }
    
    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Remind", selection: $freqStyle) {
                Text("Daily").tag(Frequency.daily)
                Text("Weekly").tag(Frequency.weekly([]))
            }
            .pickerStyle(.segmented)
            
            if case .weekly(let set) = freqStyle {
                WeekdayPicker(selection: set) { freqStyle = .weekly($0) }
            }
        }
    }
    
    private var timeSection: some View {
        Section("Dose Times") {
            ForEach(med.times.indices, id: \.self) { idx in
                HStack {
                    DatePicker("",
                               selection: Binding(
                                get: { Self.date(from: med.times[idx]) },
                                set: { med.times[idx] = Self.comps(from: $0) }),
                               displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    
                    Spacer()
                    Button(role: .destructive) {
                        med.times.remove(at: idx)
                    } label: { Image(systemName: "minus.circle") }
                }
            }
            
            DatePicker("New time", selection: $newTime,
                       displayedComponents: .hourAndMinute)
            Button("➕ Add") {
                med.times.append(Self.comps(from: newTime))
            }
        }
    }
    
    // MARK: helpers -----------------------------------------------------------
    private struct WeekdayPicker: View {
        let selection: Set<Int>
        let onToggle : (Set<Int>) -> Void
        
        private let symbols: [String] = DateFormatter().veryShortWeekdaySymbols ??
                                        ["S","M","T","W","T","F","S"]
        
        var body: some View {
            HStack {
                ForEach(1...7, id: \.self) { day in
                    let sel = selection.contains(day)
                    Text(symbols[day - 1])
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(sel ? Color.blue.opacity(0.2)
                                         : Color(.systemGray5))
                        .cornerRadius(6)
                        .onTapGesture {
                            var set = selection
                            if sel { set.remove(day) } else { set.insert(day) }
                            onToggle(set)
                        }
                }
            }
        }
    }
    
    private static func comps(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
    private static func date(from comps: DateComponents) -> Date {
        Calendar.current.date(from: comps) ?? .now
    }
}
