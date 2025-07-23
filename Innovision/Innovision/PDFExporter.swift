import Foundation
import PDFKit
import UIKit
import SwiftUI

@MainActor
final class PDFExporter: ObservableObject {
    
    func generateMedicationReport(schedule: MedicationSchedule, log: DropLog, conflicts: [MedicationConflict]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Innovision Eye Medication Tracker",
            kCGPDFContextAuthor: "Patient Report",
            kCGPDFContextTitle: "Medication Adherence Report"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let url = getDocumentsDirectory().appendingPathComponent("medication_report_\(Date().timeIntervalSince1970).pdf")
        
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                
                var yPosition: CGFloat = 50
                let leftMargin: CGFloat = 50
                let rightMargin: CGFloat = 545.2
                
                // Title
                yPosition = drawTitle(at: CGPoint(x: leftMargin, y: yPosition), width: rightMargin - leftMargin)
                yPosition += 30
                
                // Date range
                yPosition = drawDateInfo(at: CGPoint(x: leftMargin, y: yPosition))
                yPosition += 40
                
                // Medications summary
                yPosition = drawMedicationsSummary(
                    schedule: schedule,
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: rightMargin - leftMargin
                )
                yPosition += 30
                
                // Adherence data
                yPosition = drawAdherenceData(
                    schedule: schedule,
                    log: log,
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: rightMargin - leftMargin
                )
                yPosition += 30
                
                // Conflicts section
                if !conflicts.isEmpty {
                    yPosition = drawConflicts(
                        conflicts: conflicts,
                        at: CGPoint(x: leftMargin, y: yPosition),
                        width: rightMargin - leftMargin
                    )
                }
            }
            
            return url
        } catch {
            print("Error creating PDF: \(error)")
            return nil
        }
    }
    
    private func drawTitle(at point: CGPoint, width: CGFloat) -> CGFloat {
        let title = "Medication Adherence Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let attributedTitle = NSAttributedString(string: title, attributes: titleAttributes)
        let titleRect = CGRect(x: point.x, y: point.y, width: width, height: 30)
        attributedTitle.draw(in: titleRect)
        
        return point.y + 30
    }
    
    private func drawDateInfo(at point: CGPoint) -> CGFloat {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        let dateString = "Generated on: \(dateFormatter.string(from: Date()))"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        
        let attributedDate = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateRect = CGRect(x: point.x, y: point.y, width: 400, height: 20)
        attributedDate.draw(in: dateRect)
        
        return point.y + 20
    }
    
    private func drawMedicationsSummary(schedule: MedicationSchedule, at point: CGPoint, width: CGFloat) -> CGFloat {
        var yPos = point.y
        
        // Section title
        let sectionTitle = "Current Medications"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let attributedTitle = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleRect = CGRect(x: point.x, y: yPos, width: width, height: 25)
        attributedTitle.draw(in: titleRect)
        yPos += 30
        
        // Medications list
        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        for med in schedule.meds {
            let medInfo = "• \(med.name) - \(med.times.count) times per day (\(med.frequency.description))"
            let attributedMed = NSAttributedString(string: medInfo, attributes: itemAttributes)
            let medRect = CGRect(x: point.x, y: yPos, width: width, height: 20)
            attributedMed.draw(in: medRect)
            yPos += 25
        }
        
        return yPos
    }
    
    private func drawAdherenceData(schedule: MedicationSchedule, log: DropLog, at point: CGPoint, width: CGFloat) -> CGFloat {
        var yPos = point.y
        
        // Section title
        let sectionTitle = "Adherence Summary (Last 7 Days)"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let attributedTitle = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleRect = CGRect(x: point.x, y: yPos, width: width, height: 25)
        attributedTitle.draw(in: titleRect)
        yPos += 30
        
        // Adherence data
        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        for med in schedule.meds {
            let streak = log.streak(for: med, schedule: schedule)
            let todayTaken = log.takenToday(for: med)
            let todayExpected = schedule.expectedDoses(for: med)
            
            let adherenceInfo = "• \(med.name): \(todayTaken)/\(todayExpected) today, \(streak) day streak"
            let attributedAdherence = NSAttributedString(string: adherenceInfo, attributes: itemAttributes)
            let adherenceRect = CGRect(x: point.x, y: yPos, width: width, height: 20)
            attributedAdherence.draw(in: adherenceRect)
            yPos += 25
        }
        
        return yPos
    }
    
    private func drawConflicts(conflicts: [MedicationConflict], at point: CGPoint, width: CGFloat) -> CGFloat {
        var yPos = point.y
        
        // Section title
        let sectionTitle = "Medication Conflicts & Warnings"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.red
        ]
        
        let attributedTitle = NSAttributedString(string: sectionTitle, attributes: titleAttributes)
        let titleRect = CGRect(x: point.x, y: yPos, width: width, height: 25)
        attributedTitle.draw(in: titleRect)
        yPos += 30
        
        // Conflicts list
        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        for conflict in conflicts {
            let conflictInfo = "⚠️ \(conflict.medication1.name) + \(conflict.medication2.name): \(conflict.description)"
            let attributedConflict = NSAttributedString(string: conflictInfo, attributes: itemAttributes)
            let conflictRect = CGRect(x: point.x, y: yPos, width: width, height: 40)
            attributedConflict.draw(in: conflictRect)
            yPos += 45
        }
        
        return yPos
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func sharePDF(url: URL) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        return activityVC
    }
}