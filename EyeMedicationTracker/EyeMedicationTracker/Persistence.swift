import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleSchedule = MedicationSchedule(context: viewContext)
        sampleSchedule.id = UUID()
        sampleSchedule.name = "Latanoprost"
        sampleSchedule.dosage = "1 drop"
        sampleSchedule.frequency = "twice"
        sampleSchedule.times = ["08:00", "20:00"]
        sampleSchedule.startDate = Date()
        sampleSchedule.isActive = true
        sampleSchedule.reminderMinutes = 10
        sampleSchedule.color = "#0ea5e9"
        sampleSchedule.createdAt = Date()

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EyeMedicationTracker")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Core Data Extensions

extension MedicationSchedule {
    var timesArray: [String] {
        get {
            return times?.components(separatedBy: ",") ?? []
        }
        set {
            times = newValue.joined(separator: ",")
        }
    }
    
    var nextDose: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        for timeString in timesArray {
            if let nextDose = nextDoseDate(for: timeString, from: now) {
                return nextDose
            }
        }
        
        // If no doses today, get first dose tomorrow
        if let firstTime = timesArray.first,
           let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) {
            return nextDoseDate(for: firstTime, from: calendar.startOfDay(for: tomorrowDate))
        }
        
        return nil
    }
    
    private func nextDoseDate(for timeString: String, from date: Date) -> Date? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: timeString) else { return nil }
        
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let combinedDate = calendar.date(from: combinedComponents) else { return nil }
        
        return combinedDate > date ? combinedDate : nil
    }
}

extension MedicationLog {
    static func createAutomaticLog(
        for schedule: MedicationSchedule,
        deviceUsed: Bool = true,
        context: NSManagedObjectContext
    ) {
        let log = MedicationLog(context: context)
        log.id = UUID()
        log.schedule = schedule
        log.timestamp = Date()
        log.type = deviceUsed ? "automatic" : "scheduled"
        log.medicationName = schedule.name
        log.dosage = schedule.dosage
        log.deviceUsed = deviceUsed
        log.notes = deviceUsed ? "Completed via eye tracker device" : "Marked as completed"
        log.createdAt = Date()
    }
    
    static func createManualLog(
        medicationName: String,
        dosage: String?,
        timestamp: Date,
        notes: String?,
        deviceUsed: Bool = false,
        context: NSManagedObjectContext
    ) {
        let log = MedicationLog(context: context)
        log.id = UUID()
        log.timestamp = timestamp
        log.type = "manual"
        log.medicationName = medicationName
        log.dosage = dosage
        log.deviceUsed = deviceUsed
        log.notes = notes
        log.createdAt = Date()
    }
}