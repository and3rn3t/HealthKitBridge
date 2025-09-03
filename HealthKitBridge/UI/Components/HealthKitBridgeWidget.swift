import WidgetKit
import SwiftUI
import Intents

// MARK: - HealthKit Bridge Widget
struct HealthKitBridgeWidget: Widget {
    let kind: String = "HealthKitBridgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthDataProvider()) { entry in
            HealthWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HealthKit Bridge")
        .description("Monitor your health data connection status and latest metrics")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct HealthDataEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let heartRate: Double?
    let stepCount: Int?
    let lastUpdate: Date?
}

struct HealthDataProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthDataEntry {
        HealthDataEntry(
            date: Date(),
            isConnected: true,
            heartRate: 72,
            stepCount: 8420,
            lastUpdate: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthDataEntry) -> ()) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentEntry = createEntry()
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func createEntry() -> HealthDataEntry {
        let webSocketManager = WebSocketManager.shared
        let healthManager = HealthKitManager.shared
        
        return HealthDataEntry(
            date: Date(),
            isConnected: webSocketManager.isConnected,
            heartRate: healthManager.lastHeartRate,
            stepCount: Int(healthManager.lastStepCount ?? 0),
            lastUpdate: healthManager.lastDataUpdate
        )
    }
}

struct HealthWidgetEntryView: View {
    var entry: HealthDataEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(entry.isConnected ? .red : .gray)
                
                Text("HealthKit Bridge")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Circle()
                    .fill(entry.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
            }
            
            if let heartRate = entry.heartRate {
                HStack {
                    Text("\(Int(heartRate))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let stepCount = entry.stepCount {
                HStack {
                    Text("\(stepCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let lastUpdate = entry.lastUpdate {
                Text("Updated \(timeAgo(from: lastUpdate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else {
            return "\(Int(interval/3600))h ago"
        }
    }
}

@main
struct HealthKitBridgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        HealthKitBridgeWidget()
    }
}
