//
//  ContentView.swift
//  HealthKit Bridge
//
//  Created by Health Monitoring App
//

import SwiftUI
import HealthKit
import Foundation

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager.shared
    @StateObject private var healthManager = HealthKitManager.shared
    @StateObject private var apiClient = ApiClient.shared
    
    // New optimization managers
    @StateObject private var batteryManager = BatteryOptimizationManager.shared
    @StateObject private var analytics = HealthAnalyticsEngine.shared
    @StateObject private var notifications = SmartNotificationManager.shared
    @StateObject private var fallRiskEngine = FallRiskAnalysisEngine.shared
    
    // New gait analysis managers - use environment objects
    @EnvironmentObject private var fallRiskGaitManager: FallRiskGaitManager
    @EnvironmentObject private var appleWatchGaitMonitor: AppleWatchGaitMonitor
    
    @State private var isInitialized = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var lastSentData: String = "None"
    @State private var sendStatus: String = "Ready"
    @State private var showingDetailView = false
    @State private var showingDebugInfo = false
    @State private var testDataSendStatus: String = "" // New state for test data feedback
    @State private var refreshDataStatus: String = "" // New state for refresh data feedback
    @State private var forceRefresh = false // Force UI refresh trigger
    @State private var showingAnalytics = false
    @State private var showingBatteryInfo = false
    @State private var showingFallRiskDashboard = false
    
    // New iOS 16 HIG states
    @State private var selectedMetric: String? = nil
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Hero Header with Status
                        heroHeaderSection
                        
                        // Quick Actions Card (Primary CTA)
                        quickActionsCard
                        
                        // Health Metrics Grid
                        healthMetricsGrid
                        
                        // Expandable Insights Cards
                        insightsSection
                        
                        // System Status Cards
                        systemStatusSection
                        
                        // Advanced Controls (Collapsed by default)
                        advancedControlsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Bottom safe area
                }
                .scrollIndicators(.hidden)
                .background {
                    // Dynamic background with subtle gradient
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemGroupedBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await initializeApp()
                }
            }
            .alert("Notice", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .id(forceRefresh)
    }
    
    // MARK: - Hero Header Section
    private var heroHeaderSection: some View {
        VStack(spacing: 16) {
            // App Title with Status Indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HealthKit Bridge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    if !analytics.getInsightMessage().isEmpty {
                        Text(analytics.getInsightMessage())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Status Indicator
                VStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .fill(statusColor)
                                .scaleEffect(healthManager.isMonitoringActive ? 1.5 : 1.0)
                                .opacity(healthManager.isMonitoringActive ? 0.3 : 0.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: healthManager.isMonitoringActive)
                        }
                    
                    Text(overallStatus)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Real-time Data Rate (when active)
            if healthManager.isMonitoringActive {
                HStack(spacing: 16) {
                    dataRateIndicator
                    
                    if batteryManager.shouldReduceMonitoring() {
                        batterySavingIndicator
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        VStack(spacing: 16) {
            // Primary Action Button
            Button(action: {
                Task {
                    if healthManager.isMonitoringActive {
                        await stopHealthMonitoring()
                    } else {
                        if !webSocketManager.isConnected {
                            await connectWebSocket()
                        }
                        await startHealthMonitoring()
                    }
                }
            }) {
                HStack {
                    Image(systemName: healthManager.isMonitoringActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                    
                    Text(healthManager.isMonitoringActive ? "Stop Monitoring" : "Start Health Monitoring")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if healthManager.isMonitoringActive {
                        Text(String(format: "%.1f/min", healthManager.dataPointsPerMinute))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(healthManager.isMonitoringActive ? 
                              LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!webSocketManager.isConnected && !healthManager.isMonitoringActive)
            
            // Secondary Actions
            HStack(spacing: 12) {
                secondaryActionButton(
                    title: "Connect",
                    icon: "wifi.circle",
                    isEnabled: !webSocketManager.isConnected,
                    action: { Task { await connectWebSocket() } }
                )
                
                secondaryActionButton(
                    title: "Test Data",
                    icon: "heart.circle",
                    isEnabled: webSocketManager.isConnected,
                    action: { Task { await sendTestData() } }
                )
                
                secondaryActionButton(
                    title: "Refresh",
                    icon: "arrow.clockwise.circle",
                    isEnabled: webSocketManager.isConnected,
                    action: { Task { await refreshHealthData() } }
                )
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Health Metrics Grid
    private var healthMetricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            // Heart Rate Metric
            if let heartRate = healthManager.lastHeartRate {
                MetricCard(
                    title: "Heart Rate",
                    value: "\(Int(heartRate))",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red,
                    isSelected: selectedMetric == "heart_rate"
                ) {
                    selectedMetric = selectedMetric == "heart_rate" ? nil : "heart_rate"
                }
            }
            
            // Steps Metric
            if let steps = healthManager.lastStepCount {
                MetricCard(
                    title: "Steps",
                    value: "\(Int(steps))",
                    unit: "steps",
                    icon: "figure.walk",
                    color: .blue,
                    isSelected: selectedMetric == "steps"
                ) {
                    selectedMetric = selectedMetric == "steps" ? nil : "steps"
                }
            }
            
            // Energy Metric
            if let energy = healthManager.lastActiveEnergy {
                MetricCard(
                    title: "Active Energy",
                    value: "\(Int(energy))",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange,
                    isSelected: selectedMetric == "energy"
                ) {
                    selectedMetric = selectedMetric == "energy" ? nil : "energy"
                }
            }
            
            // Distance Metric
            if let distance = healthManager.lastDistance {
                MetricCard(
                    title: "Distance",
                    value: String(format: "%.1f", distance/1000),
                    unit: "km",
                    icon: "location.fill",
                    color: .green,
                    isSelected: selectedMetric == "distance"
                ) {
                    selectedMetric = selectedMetric == "distance" ? nil : "distance"
                }
            }
        }
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(spacing: 16) {
            // Health Analytics Card
            ModernExpandableCard(
                title: "Health Analytics",
                icon: "chart.line.uptrend.xyaxis",
                subtitle: analytics.dailySummary.map { "Score: \(Int($0.healthScore))/100" } ?? "No data",
                isExpanded: $showingAnalytics
            ) {
                healthAnalyticsContent
            }
            
            // Fall Risk Assessment Card
            ModernExpandableCard(
                title: "Fall Risk Assessment",
                icon: "exclamationmark.triangle",
                subtitle: fallRiskEngine.latestRiskLevel?.description ?? "No assessment",
                isExpanded: $showingFallRiskDashboard
            ) {
                fallRiskContent
            }
            
            // Battery Optimization Card
            ModernExpandableCard(
                title: "Battery Optimization",
                icon: "battery.100",
                subtitle: batteryManager.getBatteryStatusSummary(),
                isExpanded: $showingBatteryInfo
            ) {
                batteryOptimizationContent
            }
        }
    }
    
    // MARK: - System Status Section
    private var systemStatusSection: some View {
        VStack(spacing: 16) {
            // Connection Status
            SystemStatusCard(
                title: "Connection Status",
                status: webSocketManager.connectionStatus,
                isConnected: webSocketManager.isConnected,
                latency: healthManager.connectionQuality.latency,
                error: webSocketManager.lastError
            )
            
            // Performance Stats
            PerformanceStatsCard(
                totalSent: healthManager.totalDataPointsSent,
                dataRate: healthManager.dataPointsPerMinute,
                reconnects: healthManager.connectionQuality.reconnectCount,
                freshness: healthManager.healthDataFreshness
            )
        }
    }
    
    // MARK: - Advanced Controls
    private var advancedControlsSection: some View {
        ModernExpandableCard(
            title: "Debug Information",
            icon: "terminal",
            subtitle: "System details",
            isExpanded: $showingDebugInfo
        ) {
            debugContent
        }
    }
    
    // MARK: - Helper Views
    
    private var dataRateIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.caption)
                .foregroundStyle(.blue)
            Text("\(String(format: "%.1f", healthManager.dataPointsPerMinute)) data/min")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
    
    private var batterySavingIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "battery.25")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Power Saving")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }
    }
    
    private func secondaryActionButton(title: String, icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isEnabled ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
    
    // MARK: - Content Views
    
    private var healthAnalyticsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trends
            HStack {
                trendIndicator(title: "Heart Rate", trend: analytics.heartRateTrend)
                Spacer()
                trendIndicator(title: "Steps", trend: analytics.stepsTrend)
                Spacer()
                trendIndicator(title: "Energy", trend: analytics.energyTrend)
            }
            
            // Anomalies
            if !analytics.anomalies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Anomalies")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    
                    ForEach(Array(analytics.anomalies.prefix(3)), id: \.timestamp) { anomaly in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("\(anomaly.type): \(Int(anomaly.value))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Daily summary
            if let summary = analytics.dailySummary {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        summaryItem(title: "Steps", value: "\(summary.totalSteps)")
                        Spacer()
                        summaryItem(title: "Avg HR", value: "\(Int(summary.avgHeartRate))")
                        Spacer()
                        summaryItem(title: "Distance", value: String(format: "%.1f km", summary.distanceWalked))
                    }
                }
            }
        }
    }
    
    private var fallRiskContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let factors = fallRiskEngine.latestRiskFactors {
                Text("Contributing Factors")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                
                ForEach(factors.prefix(3), id: \.self) { factor in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text(factor)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if factors.count > 3 {
                    Text("... and \(factors.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            if let lastAssessment = fallRiskEngine.lastAssessmentTime {
                Text("Last Assessed: \(timeAgo(from: lastAssessment))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Navigation to comprehensive fall risk dashboard
            NavigationLink(destination: FallRiskGaitDashboardView()) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text("View Detailed Gait Analysis")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var batteryOptimizationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Interval")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.0f", batteryManager.optimizedSyncInterval))s")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Power Saving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(batteryManager.shouldReduceMonitoring() ? "Active" : "Inactive")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(batteryManager.shouldReduceMonitoring() ? .orange : .green)
            }
            
            ProgressView(value: batteryManager.batteryLevel)
                .progressViewStyle(LinearProgressViewStyle(
                    tint: batteryManager.batteryLevel > 0.2 ? .green : .red
                ))
        }
    }
    
    private var debugContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugRow(label: "User ID", value: AppConfig.shared.userId)
            debugRow(label: "Device ID", value: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")
            debugRow(label: "API Base URL", value: AppConfig.shared.apiBaseURL)
            debugRow(label: "WebSocket URL", value: AppConfig.shared.webSocketURL)
            debugRow(label: "HealthKit Status", value: healthManager.isAuthorized ? "Authorized" : "Not Authorized")
            debugRow(label: "Monitoring", value: healthManager.isMonitoringActive ? "Active" : "Inactive")
            debugRow(label: "WebSocket Mode", value: webSocketManager.isConnected ? "Connected" : "Disconnected")
            
            if let error = healthManager.lastError {
                debugRow(label: "Last Error", value: error)
            }
            
            if let wsError = webSocketManager.lastError {
                debugRow(label: "WebSocket Error", value: wsError)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if healthManager.isMonitoringActive && webSocketManager.isConnected {
            return .green
        } else if webSocketManager.isConnected {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var overallStatus: String {
        if healthManager.isMonitoringActive && webSocketManager.isConnected {
            return "Active"
        } else if webSocketManager.isConnected {
            return "Ready"
        } else {
            return "Offline"
        }
    }
    
    // MARK: - Helper Functions (keeping existing ones)
    
    private func trendIndicator(title: String, trend: HealthAnalyticsEngine.TrendDirection) -> VStack<TupleView<(Text, Text)>> {
        VStack {
            Text(trend.rawValue)
                .font(.caption)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func summaryItem(title: String, value: String) -> VStack<TupleView<(Text, Text)>> {
        VStack {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
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
    
    // MARK: - Existing Functions (keeping all functionality)
    
    private func initializeApp() async {
        print("🚀 Initializing app...")
        await healthManager.requestAuthorization()
        
        // Initialize gait analysis managers
        Task {
            await fallRiskGaitManager.requestGaitAuthorization()
            await fallRiskGaitManager.startBackgroundMonitoring()
        }
        
        await connectWebSocket()
    }
    
    private func connectWebSocket() async {
        print("🔌 Connecting WebSocket...")
        sendStatus = "Connecting..."
        
        let appConfig = AppConfig.shared
        
        if let token = await apiClient.getDeviceToken(
            userId: appConfig.userId,
            deviceType: "ios_app"
        ) {
            await webSocketManager.connect(with: token)
            sendStatus = "Connected"
        } else {
            sendStatus = "Connection failed"
            showAlert("Failed to get device token")
        }
    }
    
    private func sendTestData() async {
        print("📤 Sending test data...")
        await MainActor.run {
            sendStatus = "Sending..."
            testDataSendStatus = "Sending test data..."
        }
        
        let testData = HealthData(
            type: "heart_rate",
            value: 75.0,
            unit: "bpm",
            timestamp: Date(),
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            userId: AppConfig.shared.userId
        )
        
        do {
            try await webSocketManager.sendHealthData(testData)
            await MainActor.run {
                sendStatus = "Sent successfully"
                lastSentData = "Heart Rate: 75 bpm"
                testDataSendStatus = "✓ Test data sent successfully (Mock mode)"
            }
            
            let mode = webSocketManager.connectionStatus.contains("Mock") ? " (Mock mode)" : ""
            showAlert("Test data sent successfully: Heart Rate 75 BPM\(mode)")
            
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.sendStatus = "Ready"
                    self.testDataSendStatus = ""
                }
            }
        } catch {
            await MainActor.run {
                sendStatus = "Send failed"
                testDataSendStatus = "✗ Failed to send test data"
            }
            showAlert("Failed to send test data: \(error.localizedDescription)")
            
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.testDataSendStatus = ""
                }
            }
        }
    }
    
    private func startHealthMonitoring() async {
        print("📊 Starting health monitoring...")
        await MainActor.run {
            isInitialized = true
            sendStatus = "Monitoring active"
        }
        
        await healthManager.startLiveDataStreaming(webSocketManager: webSocketManager)
        showAlert("Health monitoring started successfully")
    }
    
    private func refreshHealthData() async {
        print("🔄 Manually refreshing health data...")
        await MainActor.run {
            refreshDataStatus = "Refreshing health data..."
        }
        
        do {
            try await healthManager.sendCurrentHealthData()
            await MainActor.run {
                refreshDataStatus = "✓ Health data refreshed successfully"
            }
            
            let summary = healthManager.getHealthDataSummary()
            let message = summary.isEmpty ? 
                "Health data refresh completed" : 
                "Health data refreshed: \(summary)"
            showAlert(message)
            
        } catch {
            await MainActor.run {
                refreshDataStatus = "✗ Failed to refresh health data"
            }
            showAlert("Failed to refresh health data: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.refreshDataStatus = ""
            }
        }
    }
    
    private func stopHealthMonitoring() async {
        print("⏹️ Stopping health monitoring...")
        healthManager.stopMonitoring()
        showAlert("Health monitoring stopped")
    }
    
    private func showAlert(_ message: String) {
        Task { @MainActor in
            alertMessage = message
            showingAlert = true
        }
    }
}

// MARK: - Modern UI Components

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.blue, lineWidth: 2)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ModernExpandableCard<Content: View>: View {
    let title: String
    let icon: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SystemStatusCard: View {
    let title: String
    let status: String
    let isConnected: Bool
    let latency: Double
    let error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .fill(isConnected ? Color.green : Color.red)
                            .scaleEffect(isConnected ? 1.5 : 1.0)
                            .opacity(isConnected ? 0.3 : 0.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isConnected)
                    }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if latency > 0 {
                    Text("\(Int(latency * 1000))ms")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PerformanceStatsCard: View {
    let totalSent: Int
    let dataRate: Double
    let reconnects: Int
    let freshness: [String: Date]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                statItem(title: "Total Sent", value: "\(totalSent)")
                Spacer()
                statItem(title: "Rate", value: String(format: "%.1f/min", dataRate))
                Spacer()
                statItem(title: "Reconnects", value: "\(reconnects)")
            }
            
            if !freshness.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Updates")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(freshness.keys.sorted().prefix(3)), id: .self) { key in
                        if let date = freshness[key] {
                            HStack {
                                Text(key.capitalized)
                                    .font(.caption)
                                Spacer()
                                Text(timeAgo(from: date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(WebSocketManager.shared)
}
