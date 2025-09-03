import SwiftUI
import HealthKit
import WatchConnectivity

// MARK: - Apple Watch App
@main
struct HealthKitBridgeWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var healthManager = WatchHealthManager.shared
    @State private var currentHeartRate: Double = 0
    @State private var isMonitoring = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Heart Rate Display
                VStack {
                    Text("\(Int(currentHeartRate))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                // Control Buttons
                VStack(spacing: 8) {
                    Button(action: toggleMonitoring) {
                        HStack {
                            Image(systemName: isMonitoring ? "stop.fill" : "play.fill")
                            Text(isMonitoring ? "Stop" : "Start")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isMonitoring ? .red : .green)
                    
                    Button("Send Data") {
                        sendCurrentData()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(watchConnectivity.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(watchConnectivity.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Health Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            healthManager.startHeartRateMonitoring { heartRate in
                currentHeartRate = heartRate
            }
        }
    }
    
    private func toggleMonitoring() {
        isMonitoring.toggle()
        
        if isMonitoring {
            healthManager.startContinuousMonitoring()
        } else {
            healthManager.stopContinuousMonitoring()
        }
    }
    
    private func sendCurrentData() {
        watchConnectivity.sendHeartRate(currentHeartRate)
    }
}

// MARK: - Watch Health Manager
class WatchHealthManager: NSObject, ObservableObject {
    static let shared = WatchHealthManager()
    
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var workoutSession: HKWorkoutSession?
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("❌ Watch authorization failed: \(error)")
            }
        }
    }
    
    func startHeartRateMonitoring(completion: @escaping (Double) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample],
                  let latestSample = samples.last else { return }
            
            let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                completion(heartRate)
            }
        }
        
        query.updateHandler = { query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample],
                  let latestSample = samples.last else { return }
            
            let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                completion(heartRate)
            }
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    func startContinuousMonitoring() {
        // Start a workout session for continuous monitoring
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.startActivity(with: Date())
        } catch {
            print("❌ Failed to start workout session: \(error)")
        }
    }
    
    func stopContinuousMonitoring() {
        workoutSession?.end()
        workoutSession = nil
        
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }
}

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var isConnected = false
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendHeartRate(_ heartRate: Double) {
        guard WCSession.default.isReachable else { return }
        
        let message = [
            "type": "heart_rate",
            "value": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send heart rate: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iOS app if needed
    }
}

#Preview {
    WatchContentView()
}
