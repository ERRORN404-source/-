import SwiftUI

public struct ContentView: View {
    @StateObject private var tracker = TrackingManager.shared
    @State private var hostIP: String = "192.168.1.100"
    @State private var useUsbTunnel: Bool = false
    @State private var isOledSleep: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isOledSleep {
                // OLED True Black View: (RGB 0,0,0 - 0 nits, organic pixels physically off)
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture(count: 2) {
                        isOledSleep = false
                        UIScreen.main.brightness = 0.5
                    }
                    .overlay(
                        VStack(spacing: 8) {
                            Text("• OLED Sleep Active (\(tracker.fps) FPS)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.2))
                            Text("Double-tap screen to wake UI")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(white: 0.15))
                        }
                    )
            } else {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("VTUBER TRACKER")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("ARKit TrueDepth + Apple Vision Hands")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Connection Configuration Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CONNECTION SETTINGS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        
                        Toggle("USB Cable Tunnel (usbmuxd)", isOn: $useUsbTunnel)
                            .foregroundColor(.white)
                            .onChange(of: useUsbTunnel) { enabled in
                                if enabled {
                                    hostIP = "127.0.0.1"
                                }
                            }
                        
                        if !useUsbTunnel {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Host PC Wi-Fi IP Address")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                TextField("192.168.x.x", text: $hostIP)
                                    .padding(10)
                                    .background(Color(white: 0.15))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocapitalization(.none)
                            }
                        } else {
                            Text("Target: 127.0.0.1 (Via Lightning / USB cable with iproxy)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Streaming Status Badge
                    if tracker.isStreaming {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("STREAMING ACTIVE: \(tracker.fps) FPS")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            if tracker.isStreaming {
                                tracker.stop()
                            } else {
                                let mode: TransportMode = useUsbTunnel ? .usbTcp : .udp
                                tracker.start(host: hostIP, port: 39539, mode: mode)
                            }
                        }) {
                            Text(tracker.isStreaming ? "STOP STREAMING" : "START CAPTURE (60 FPS)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(tracker.isStreaming ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        if tracker.isStreaming {
                            Button(action: {
                                isOledSleep = true
                                UIScreen.main.brightness = 0.0 // Dim backlight to absolute minimum
                            }) {
                                HStack {
                                    Image(systemName: "moon.fill")
                                    Text("Engage OLED Black Mode")
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.05).ignoresSafeArea())
            }
        }
    }
}
