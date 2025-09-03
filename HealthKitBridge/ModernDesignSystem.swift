//
//  ModernDesignSystem.swift
//  HealthKit Bridge
//
//  Enhanced iOS 16 HIG Design System Components
//

import SwiftUI

// MARK: - Design Tokens

extension Color {
    static let healthRed = Color(red: 0.98, green: 0.26, blue: 0.28)
    static let healthBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let healthOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let healthGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let systemGray7 = Color(red: 0.949, green: 0.949, blue: 0.969)
}

extension Font {
    static let largeNumber = Font.system(size: 32, weight: .bold, design: .rounded)
    static let mediumNumber = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let smallNumber = Font.system(size: 18, weight: .medium, design: .rounded)
}

// MARK: - Modern Card Components

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            }
    }
}

struct HeroCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
    }
}

// MARK: - Interactive Components

struct ModernToggle: View {
    @Binding var isOn: Bool
    let title: String
    let subtitle: String?
    let icon: String
    
    init(_ title: String, subtitle: String? = nil, icon: String, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGSize
    
    init(progress: Double, color: Color = .blue, lineWidth: CGFloat = 8, size: CGSize = CGSize(width: 60, height: 60)) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Status Indicators

struct StatusBadge: View {
    let text: String
    let style: BadgeStyle
    
    enum BadgeStyle {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var backgroundColor: Color {
            return color.opacity(0.1)
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(style.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(style.backgroundColor, in: Capsule())
    }
}

struct LiveIndicator: View {
    let isActive: Bool
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? .red : .secondary)
                .frame(width: 8, height: 8)
                .overlay {
                    if isActive {
                        Circle()
                            .fill(.red)
                            .scaleEffect(1.5)
                            .opacity(0.6)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
                    }
                }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Data Visualization

struct MiniChart: View {
    let dataPoints: [Double]
    let color: Color
    let showGradient: Bool
    
    init(dataPoints: [Double], color: Color = .blue, showGradient: Bool = true) {
        self.dataPoints = dataPoints
        self.color = color
        self.showGradient = showGradient
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue = dataPoints.max() ?? 1
            let minValue = dataPoints.min() ?? 0
            let range = maxValue - minValue
            
            Path { path in
                guard dataPoints.count > 1 else { return }
                
                let stepWidth = width / CGFloat(dataPoints.count - 1)
                
                for (index, point) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepWidth
                    let normalizedValue = range > 0 ? (point - minValue) / range : 0.5
                    let y = height - (CGFloat(normalizedValue) * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            
            if showGradient {
                Path { path in
                    guard dataPoints.count > 1 else { return }
                    
                    let stepWidth = width / CGFloat(dataPoints.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, point) in dataPoints.enumerated() {
                        let x = CGFloat(index) * stepWidth
                        let normalizedValue = range > 0 ? (point - minValue) / range : 0.5
                        let y = height - (CGFloat(normalizedValue) * height)
                        
                        if index == 0 {
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Advanced Metric Display

struct DetailedMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: TrendDirection
    let trendValue: String
    let icon: String
    let color: Color
    let chartData: [Double]
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .secondary
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundStyle(trend.color)
                    
                    Text(trendValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(trend.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trend.color.opacity(0.1), in: Capsule())
            }
            
            // Value
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline) {
                    Text(value)
                        .font(.largeNumber)
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            
            // Mini Chart
            if !chartData.isEmpty {
                MiniChart(dataPoints: chartData, color: color)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Animated Components

struct PulsingCircle: View {
    let color: Color
    let size: CGFloat
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .fill(color)
                    .scaleEffect(isPulsing ? 2.0 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
            }
            .onAppear {
                isPulsing = true
            }
    }
}

struct LoadingDots: View {
    @State private var animationIndex = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationIndex == index ? 1.2 : 0.8)
                    .opacity(animationIndex == index ? 1.0 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationIndex = (animationIndex + 1) % 3
            }
        }
    }
}

// MARK: - Button Styles

struct ModernButtonStyle: ButtonStyle {
    let style: ButtonStyleType
    
    enum ButtonStyleType {
        case primary, secondary, destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .clear
            case .destructive: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .blue
            case .destructive: return .white
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .primary: return nil
            case .secondary: return .blue
            case .destructive: return nil
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(style.backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if let borderColor = style.borderColor {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Layout Helpers

struct AdaptiveStack<Content: View>: View {
    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        if sizeClass == .compact {
            VStack(alignment: horizontalAlignment, spacing: spacing) {
                content
            }
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct ModernDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Hero Card Example
                HeroCard {
                    VStack {
                        Text("Hero Card")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("This is a modern hero card with glass morphism")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Metric Cards
                HStack(spacing: 16) {
                    DetailedMetricCard(
                        title: "Heart Rate",
                        value: "72",
                        unit: "BPM",
                        trend: .up,
                        trendValue: "+2.1%",
                        icon: "heart.fill",
                        color: .healthRed,
                        chartData: [68, 70, 72, 71, 72, 74, 72]
                    )
                    
                    DetailedMetricCard(
                        title: "Steps",
                        value: "8,421",
                        unit: "steps",
                        trend: .down,
                        trendValue: "-1.3%",
                        icon: "figure.walk",
                        color: .healthBlue,
                        chartData: [8200, 8400, 8500, 8300, 8421, 8350, 8421]
                    )
                }
                
                // Status Badges
                HStack {
                    StatusBadge(text: "Connected", style: .success)
                    StatusBadge(text: "Low Battery", style: .warning)
                    StatusBadge(text: "Error", style: .error)
                    StatusBadge(text: "Info", style: .info)
                }
                
                // Live Indicators
                HStack {
                    LiveIndicator(isActive: true, title: "LIVE")
                    LiveIndicator(isActive: false, title: "Offline")
                }
                
                // Progress Ring
                ProgressRing(progress: 0.75, color: .healthGreen)
                
                // Loading Animation
                LoadingDots()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
#endif