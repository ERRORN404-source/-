import SwiftUI
import UIKit

// MARK: - App Themes
public enum AppTheme: String, CaseIterable, Identifiable {
    case cyberpunk = "Cyberpunk Neon"
    case oledBlack = "OLED Stealth"
    case sakura = "Sakura Blossom"
    case deepOcean = "Deep Ocean"
    case sunset = "Sunset Amber"
    
    public var id: String { rawValue }
    
    public var primaryColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 0.0, green: 0.95, blue: 0.95) // Cyan
        case .oledBlack: return Color(red: 0.0, green: 1.0, blue: 0.5) // Matrix Green
        case .sakura: return Color(red: 1.0, green: 0.45, blue: 0.75) // Sakura Pink
        case .deepOcean: return Color(red: 0.2, green: 0.6, blue: 1.0) // Aqua Blue
        case .sunset: return Color(red: 1.0, green: 0.55, blue: 0.2) // Amber
        }
    }
    
    public var secondaryColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 0.8, green: 0.1, blue: 0.9)
        case .oledBlack: return Color(red: 0.1, green: 0.4, blue: 0.2)
        case .sakura: return Color(red: 0.6, green: 0.2, blue: 0.8)
        case .deepOcean: return Color(red: 0.0, green: 0.8, blue: 0.8)
        case .sunset: return Color(red: 0.9, green: 0.2, blue: 0.3)
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .oledBlack: return Color.black
        case .cyberpunk: return Color(red: 0.05, green: 0.05, blue: 0.08)
        case .sakura: return Color(red: 0.08, green: 0.05, blue: 0.09)
        case .deepOcean: return Color(red: 0.03, green: 0.06, blue: 0.12)
        case .sunset: return Color(red: 0.09, green: 0.05, blue: 0.04)
        }
    }
    
    public var cardBackground: Color {
        switch self {
        case .oledBlack: return Color(white: 0.07)
        case .cyberpunk: return Color(red: 0.09, green: 0.10, blue: 0.15)
        case .sakura: return Color(red: 0.14, green: 0.09, blue: 0.16)
        case .deepOcean: return Color(red: 0.07, green: 0.12, blue: 0.20)
        case .sunset: return Color(red: 0.15, green: 0.09, blue: 0.08)
        }
    }
}

public struct ContentView: View {
    @StateObject private var tracker = TrackingManager.shared
    
    // Persistent Preferences (AppStorage)
    @AppStorage("hostIP") private var hostIP: String = "192.168.1.100"
    @AppStorage("hostPort") private var hostPort: String = "39539"
    @AppStorage("useUsbTunnel") private var useUsbTunnel: Bool = false
    @AppStorage("useTcp") private var useTcp: Bool = false
    @AppStorage("appTheme") private var selectedTheme: String = AppTheme.cyberpunk.rawValue
    @AppStorage("customAppTitle") private var customAppTitle: String = "VTUBER TRACKER"
    @AppStorage("enableHandTracking") private var enableHandTracking: Bool = true
    @AppStorage("showLiveTelemetry") private var showLiveTelemetry: Bool = true
    @AppStorage("eyeBoost") private var eyeBoost: Double = 1.0
    @AppStorage("mouthBoost") private var mouthBoost: Double = 1.0
    
    // Ephemeral State
    @State private var isOledSleep: Bool = false
    @State private var selectedTab: Int = 0
    
    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .cyberpunk
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isOledSleep {
                // OLED True Black Screen (0 nits on organic pixels)
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture(count: 2) {
                        isOledSleep = false
                        UIScreen.main.brightness = 0.5
                    }
                    .overlay(
                        VStack(spacing: 12) {
                            Circle()
                                .fill(tracker.isStreaming ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text("OLED Sleep Active (\(tracker.fps) FPS)")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(white: 0.35))
                            Text("Double-tap screen to wake interface")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.2))
                        }
                    )
            } else {
                currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    headerBar
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        dashboardView
                            .tag(0)
                        
                        telemetryAndTuningView
                            .tag(1)
                        
                        appearanceSettingsView
                            .tag(2)
                        
                        networkSettingsView
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Bottom Navigation Bar
                    customTabBar
                }
            }
        }
        .onAppear {
            tracker.enableHandTracking = enableHandTracking
        }
        .onChange(of: enableHandTracking) { val in
            tracker.enableHandTracking = val
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customAppTitle)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(tracker.isStreaming ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(tracker.isStreaming ? "ONLINE • \(tracker.fps) FPS" : "STANDBY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(tracker.isStreaming ? .green : .orange)
                }
            }
            
            Spacer()
            
            if tracker.isStreaming {
                Button(action: {
                    isOledSleep = true
                    UIScreen.main.brightness = 0.0
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                        Text("OLED")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(currentTheme.primaryColor)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(currentTheme.primaryColor.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 14)
        .background(currentTheme.cardBackground.opacity(0.85))
    }
    
    // MARK: - Tab 1: Dashboard
    private var dashboardView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Main Status Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TARGET HOST")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                            Text(useUsbTunnel ? "127.0.0.1 (USB Cable)" : "\(hostIP):\(hostPort)")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("PROTOCOL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                            Text(useTcp ? "TCP Stream" : "UDP Datagram")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 20) {
                        metricPill(title: "FPS", value: "\(tracker.fps)")
                        metricPill(title: "PACKETS", value: "\(tracker.packetsSent)")
                        metricPill(title: "HANDS", value: enableHandTracking ? (tracker.liveHasLeftHand || tracker.liveHasRightHand ? "TRACKED" : "SEARCH") : "OFF")
                    }
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Live Blendshapes Preview Card
                if showLiveTelemetry {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REAL-TIME ARKIT METRICS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(currentTheme.primaryColor)
                        
                        blendshapeMeter(name: "Jaw Open", value: tracker.liveJawOpen)
                        blendshapeMeter(name: "Eye Blink Left", value: tracker.liveEyeBlinkLeft)
                        blendshapeMeter(name: "Eye Blink Right", value: tracker.liveEyeBlinkRight)
                        blendshapeMeter(name: "Smile", value: tracker.liveMouthSmile)
                        
                        HStack {
                            Text("Vision Hands:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("L: \(tracker.liveHasLeftHand ? "ACTIVE" : "-") | R: \(tracker.liveHasRightHand ? "ACTIVE" : "-")")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(tracker.liveHasLeftHand || tracker.liveHasRightHand ? .green : .gray)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(currentTheme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Primary Big Action Button
                Button(action: {
                    if tracker.isStreaming {
                        tracker.stop()
                    } else {
                        let portNum = UInt16(hostPort) ?? 39539
                        let mode: TransportMode = useTcp ? .usbTcp : .udp
                        let target = useUsbTunnel ? "127.0.0.1" : hostIP
                        tracker.start(host: target, port: portNum, mode: mode)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: tracker.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                        Text(tracker.isStreaming ? "STOP CAPTURE" : "START CAPTURE (60 FPS)")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(tracker.isStreaming ? Color.red : currentTheme.primaryColor)
                    .foregroundColor(tracker.isStreaming ? .white : Color.black)
                    .cornerRadius(16)
                    .shadow(color: (tracker.isStreaming ? Color.red : currentTheme.primaryColor).opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Tab 2: Telemetry & Tuning
    private var telemetryAndTuningView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("TRACKING ENGINES")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Toggle("Apple Vision Hand Pose Tracking", isOn: $enableHandTracking)
                        .foregroundColor(.white)
                    
                    Text("Detects 21 3D finger joints for both hands using the A15 Bionic Neural Engine. Turn off to maximize battery.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Toggle("Show Live ARKit Debug Meters", isOn: $showLiveTelemetry)
                        .foregroundColor(.white)
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("EXPRESSION MULTIPLIERS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Eye Blink Boost")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1fx", eyeBoost))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                        }
                        Slider(value: $eyeBoost, in: 0.5...2.5, step: 0.1)
                            .tint(currentTheme.primaryColor)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Mouth Movement Boost")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1fx", mouthBoost))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                        }
                        Slider(value: $mouthBoost, in: 0.5...2.5, step: 0.1)
                            .tint(currentTheme.primaryColor)
                    }
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Tab 3: Appearance & Theme
    private var appearanceSettingsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("COLOR THEME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: {
                            selectedTheme = theme.rawValue
                        }) {
                            HStack {
                                Circle()
                                    .fill(theme.primaryColor)
                                    .frame(width: 16, height: 16)
                                Text(theme.rawValue)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                if selectedTheme == theme.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.primaryColor)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("INTERFACE CUSTOMIZATION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Text("App Header Title")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Enter Title", text: $customAppTitle)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Tab 4: Network Settings
    private var networkSettingsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("NETWORK & TRANSPORT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Toggle("USB Cable Tunnel Mode (usbmuxd)", isOn: $useUsbTunnel)
                        .foregroundColor(.white)
                    
                    if useUsbTunnel {
                        Text("Connected via Lightning/USB-C. Uses localhost 127.0.0.1 tunnel through Windows USB driver.")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Host PC IP Address")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            TextField("192.168.x.x", text: $hostIP)
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target Port")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        TextField("39539", text: $hostPort)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Toggle("Use TCP Protocol (instead of UDP)", isOn: $useTcp)
                        .foregroundColor(.white)
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack {
            tabBarItem(index: 0, title: "Stream", icon: "dot.radiowaves.left.and.right")
            Spacer()
            tabBarItem(index: 1, title: "Tuning", icon: "slider.horizontal.3")
            Spacer()
            tabBarItem(index: 2, title: "Theme", icon: "paintpalette.fill")
            Spacer()
            tabBarItem(index: 3, title: "Network", icon: "network")
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(currentTheme.cardBackground.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.08)),
            alignment: .top
        )
    }
    
    private func tabBarItem(index: Int, title: String, icon: String) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium))
            }
            .foregroundColor(selectedTab == index ? currentTheme.primaryColor : Color.gray)
        }
    }
    
    // MARK: - Helper UI Components
    private func metricPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func blendshapeMeter(name: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.primaryColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(currentTheme.primaryColor)
                        .frame(width: max(0, min(geo.size.width * CGFloat(value), geo.size.width)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
