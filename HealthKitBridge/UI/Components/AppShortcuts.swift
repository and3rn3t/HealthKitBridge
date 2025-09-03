import AppIntents
import SwiftUI

// MARK: - App Shortcuts for iOS 16+
struct SendHealthDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Health Data"
    static var description = IntentDescription("Instantly send current health data to your connected server")
    
    func perform() async throws -> some IntentResult {
        let healthManager = HealthKitManager.shared
        let webSocketManager = WebSocketManager.shared
        
        // Send latest health data
        await healthManager.sendAllHealthData()
        
        return .result(dialog: "Health data sent successfully!")
    }
}

struct CheckConnectionStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Connection"
    static var description = IntentDescription("Check your HealthKit Bridge connection status")
    
    func perform() async throws -> some IntentResult {
        let webSocketManager = WebSocketManager.shared
        let status = webSocketManager.isConnected ? "Connected" : "Disconnected"
        
        return .result(dialog: "Connection status: \(status)")
    }
}

struct HealthKitBridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendHealthDataIntent(),
            phrases: [
                "Send my health data with \(.applicationName)",
                "Update health data in \(.applicationName)"
            ],
            shortTitle: "Send Health Data",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: CheckConnectionStatusIntent(),
            phrases: [
                "Check connection in \(.applicationName)",
                "Is \(.applicationName) connected?"
            ],
            shortTitle: "Check Connection",
            systemImageName: "network"
        )
    }
}
