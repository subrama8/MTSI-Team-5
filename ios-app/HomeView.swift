import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var log: DropLog
    
    var body: some View {
        VStack(spacing: 20) {
            Text("👏 Streak: \(log.streak) days")
                .font(.title2).bold()
            
            Button("Manual drop logged") {
                // Demo: record against first med
                if let med = log.events.last?.medName ?? nil {
                    log.record(Medication(name: med, color: .blue, times: []), auto: false)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
} 