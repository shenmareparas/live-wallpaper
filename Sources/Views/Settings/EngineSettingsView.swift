import SwiftUI
import AppKit

struct EngineSettingsView: View {
    @Binding var playbackSpeed: Double
    @Binding var transitionDuration: Double
    @Binding var shuffleEnabled: Bool
    @Binding var shuffleInterval: Double
    @Binding var launchAtLogin: Bool
    let toggleLaunchAtLogin: (Bool) -> Void
    
    var body: some View {
        Form {
            Section {
                // Playback speed
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Playback Speed")
                        Spacer()
                        Text(String(format: "%.2fx", playbackSpeed))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25) {
                        Text("Playback Speed")
                    } minimumValueLabel: {
                        Text("0.5x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("2.0x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button(action: { playbackSpeed = speed }) {
                                Text(String(format: "%.1fx", speed))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                            .buttonStyle(.bordered)
                            .tint(playbackSpeed == speed ? .accentColor : nil)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 2)
                }
                
                // Fade duration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Fade Transition")
                        Spacer()
                        Text(String(format: "%.1fs", transitionDuration))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $transitionDuration, in: 0.1...2.0, step: 0.1) {
                        Text("Fade Transition")
                    } minimumValueLabel: {
                        Text("0.1s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("2.0s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Button("Instant (0.1s)") { transitionDuration = 0.1 }
                            .buttonStyle(.bordered)
                            .tint(transitionDuration == 0.1 ? .accentColor : nil)
                            .controlSize(.small)
                        Button("Balanced (0.6s)") { transitionDuration = 0.6 }
                            .buttonStyle(.bordered)
                            .tint(transitionDuration == 0.6 ? .accentColor : nil)
                            .controlSize(.small)
                        Button("Gradual (1.5s)") { transitionDuration = 1.5 }
                            .buttonStyle(.bordered)
                            .tint(transitionDuration == 1.5 ? .accentColor : nil)
                            .controlSize(.small)
                    }
                    .padding(.top, 2)
                }
            } header: {
                Text("Video Engine")
            } footer: {
                Text("Adjust playback rate and smoothness during live wallpaper cross-fades.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Rotate Wallpapers Automatically", isOn: $shuffleEnabled)
                
                if shuffleEnabled {
                    Picker("Rotation Interval", selection: $shuffleInterval) {
                        Text("1 Minute").tag(60.0)
                        Text("5 Minutes").tag(300.0)
                        Text("15 Minutes").tag(900.0)
                        Text("30 Minutes").tag(1800.0)
                        Text("1 Hour").tag(3600.0)
                    }
                }
            } header: {
                Text("Automatic Rotation")
            } footer: {
                Text("Sequentially or randomly transitions through wallpapers stored in your local library.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Launch Application at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            } header: {
                Text("Startup & System")
            }
            
            Section {
                Button("Reset Engine to Defaults") {
                    playbackSpeed = 1.0
                    transitionDuration = 0.5
                    shuffleEnabled = false
                    shuffleInterval = 300.0
                }
                
                Button(action: openSystemWallpaperSettings) {
                    Label("Open Native Wallpaper Settings...", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openSystemWallpaperSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
