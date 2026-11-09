import SwiftUI
import UIKit
import AVFoundation

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
    
    // Persistent Preferences
    @AppStorage("selectedConnection") private var selectedConnectionRaw: String = ConnectionType.wifi.rawValue
    @AppStorage("wifiHostIP") private var wifiHostIP: String = "192.168.1.100"
    @AppStorage("wanHostIP") private var wanHostIP: String = "203.0.113.195"
    @AppStorage("hostPort") private var hostPort: String = "39539"
    @AppStorage("appTheme") private var selectedTheme: String = AppTheme.cyberpunk.rawValue
    @AppStorage("customAppTitle") private var customAppTitle: String = "VTUBER TRACKER"
    @AppStorage("enableHandTracking") private var enableHandTracking: Bool = true
    @AppStorage("showLiveTelemetry") private var showLiveTelemetry: Bool = true
    @AppStorage("eyeBoost") private var eyeBoost: Double = 1.0
    @AppStorage("mouthBoost") private var mouthBoost: Double = 1.0
    
    // Ephemeral State
    @State private var isOledSleep: Bool = false
    @State private var selectedTab: Int = 0
    
    private var currentConnection: ConnectionType {
        ConnectionType(rawValue: selectedConnectionRaw) ?? .wifi
    }
    
    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .cyberpunk
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isOledSleep {
                // OLED True Black Screen (0 nits)
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
                            Text("Двойной тап для пробуждения")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.2))
                        }
                    )
            } else {
                currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerBar
                    
                    TabView(selection: $selectedTab) {
                        dashboardView
                            .tag(0)
                        
                        tuningView
                            .tag(1)
                        
                        appearanceView
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
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
    
    // MARK: - Header Bar
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
            VStack(spacing: 16) {
                // Real-Time Telemetry Stats Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("РЕЖИМ ПОДКЛЮЧЕНИЯ")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                            Text(currentConnection.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("ЦЕЛЬ")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.primaryColor)
                            Text(tracker.isStreaming ? tracker.currentHost : activeTargetDisplay)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 16) {
                        metricPill(title: "FPS", value: "\(tracker.fps)")
                        metricPill(title: "ПАКЕТЫ", value: "\(tracker.packetsSent)")
                        metricPill(title: "РУКИ", value: enableHandTracking ? (tracker.liveHasLeftHand || tracker.liveHasRightHand ? "ДА" : "ПОИСК") : "ВЫКЛ")
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
                
                // Live Blendshapes Preview
                if showLiveTelemetry {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ЖИВОЙ ТРЕКИНГ (ARKIT)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(currentTheme.primaryColor)
                        
                        blendshapeMeter(name: "Рот (Jaw Open)", value: tracker.liveJawOpen)
                        blendshapeMeter(name: "Левый глаз", value: tracker.liveEyeBlinkLeft)
                        blendshapeMeter(name: "Правый глаз", value: tracker.liveEyeBlinkRight)
                        blendshapeMeter(name: "Улыбка", value: tracker.liveMouthSmile)
                    }
                    .padding()
                    .background(currentTheme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Camera Permission Warning if needed
                if tracker.cameraPermissionDenied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Разрешите доступ к камере в Настройках iPhone")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // MARK: - Connection Selector & Start Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("ВЫБОР КАНАЛА ПЕРЕДАЧИ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    // 4-Way Mode Selector (USB, Wi-Fi, Internet, Bluetooth)
                    HStack(spacing: 8) {
                        ForEach(ConnectionType.allCases) { conn in
                            Button(action: {
                                selectedConnectionRaw = conn.rawValue
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: conn.icon)
                                        .font(.system(size: 18))
                                    Text(conn.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(currentConnection == conn ? currentTheme.primaryColor : Color.black.opacity(0.3))
                                .foregroundColor(currentConnection == conn ? Color.black : Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(currentConnection == conn ? currentTheme.primaryColor : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Dynamic Input Field based on selected connection
                    VStack(alignment: .leading, spacing: 6) {
                        switch currentConnection {
                        case .usb:
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Кабель Lightning / USB-C (127.0.0.1 tunnel)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                            
                        case .wifi:
                            Text("IP-адрес компьютера в локальной сети:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            TextField("192.168.x.x", text: $wifiHostIP)
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .keyboardType(.numbersAndPunctuation)
                                .autocapitalization(.none)
                            
                        case .internet:
                            Text("Внешний IP адрес или домен (WAN / VPN):")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            TextField("например: 95.161.x.x или my-host.com", text: $wanHostIP)
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                            
                        case .bluetooth:
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(currentTheme.primaryColor)
                                Text("Bluetooth LE трансляция (ПК подключается по BLE / BT Tethering)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // START / STOP BUTTON
                    Button(action: {
                        if tracker.isStreaming {
                            tracker.stop()
                        } else {
                            let portNum = UInt16(hostPort) ?? 39539
                            let targetHost: String
                            switch currentConnection {
                            case .usb: targetHost = "127.0.0.1"
                            case .wifi: targetHost = wifiHostIP
                            case .internet: targetHost = wanHostIP
                            case .bluetooth: targetHost = "172.20.10.1"
                            }
                            tracker.start(connectionType: currentConnection, host: targetHost, port: portNum)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: tracker.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(tracker.isStreaming ? "ОСТАНОВИТЬ ТРАНСЛЯЦИЮ" : "СТАРТ ТРАНСЛЯЦИИ (60 FPS)")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(tracker.isStreaming ? Color.red : currentTheme.primaryColor)
                        .foregroundColor(tracker.isStreaming ? .white : Color.black)
                        .cornerRadius(16)
                        .shadow(color: (tracker.isStreaming ? Color.red : currentTheme.primaryColor).opacity(0.45), radius: 8, y: 4)
                    }
                    .padding(.top, 4)
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
    
    // MARK: - Tab 2: Tuning
    private var tuningView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ДВИЖКИ ТРЕКИНГА")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Toggle("Трекинг рук (Apple Vision Hands)", isOn: $enableHandTracking)
                        .foregroundColor(.white)
                    
                    Text("Распознает 21 сустав пальцев обеих рук в реальном времени. Отключите для максимального сбережения батареи.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Toggle("Отображать шкалы ARKit в реальном времени", isOn: $showLiveTelemetry)
                        .foregroundColor(.white)
                }
                .padding()
                .background(currentTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("УСИЛЕНИЕ МИМИКИ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Усиление моргания глаз")
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
                            Text("Усиление движений рта")
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
    
    // MARK: - Tab 3: Appearance
    private var appearanceView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ЦВЕТОВАЯ ТЕМА")
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
                    Text("НАСТРОЙКА ИНТЕРФЕЙСА")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.primaryColor)
                    
                    Text("Заголовок приложения")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Введите заголовок", text: $customAppTitle)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Text("Сетевой порт:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("39539", text: $hostPort)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
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
            tabBarItem(index: 0, title: "Стрим", icon: "dot.radiowaves.left.and.right")
            Spacer()
            tabBarItem(index: 1, title: "Тюнинг", icon: "slider.horizontal.3")
            Spacer()
            tabBarItem(index: 2, title: "Тема", icon: "paintpalette.fill")
        }
        .padding(.horizontal, 36)
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
    
    // MARK: - Helpers
    private var activeTargetDisplay: String {
        switch currentConnection {
        case .usb: return "127.0.0.1 (USB)"
        case .wifi: return wifiHostIP
        case .internet: return wanHostIP
        case .bluetooth: return "BLE Direct"
        }
    }
    
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
