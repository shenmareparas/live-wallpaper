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
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Configure rendering performance and system behaviors.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            // Section 1: Video Engine Adjustments
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 12, weight: .bold))
                    Text("Video Engine Adjustments")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                
                Divider()
                
                // Playback Speed
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Playback Speed")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(String(format: "%.2fx", playbackSpeed))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                        
                        Image(systemName: "hare.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Speed Presets
                    HStack(spacing: 6) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button(action: { playbackSpeed = speed }) {
                                Text(String(format: "%.1fx", speed))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                    .background(playbackSpeed == speed ? Color.accentColor : Color.primary.opacity(0.04))
                                    .foregroundColor(playbackSpeed == speed ? .white : .primary)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 2)
                }
                
                // Transition Duration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Transition Fade")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(String(format: "%.1fs", transitionDuration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $transitionDuration, in: 0.1...2.0, step: 0.1)
                        
                        Image(systemName: "wind")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Transition Presets
                    HStack(spacing: 6) {
                        Button(action: { transitionDuration = 0.1 }) {
                            Text("Instant (0.1s)")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(transitionDuration == 0.1 ? Color.accentColor : Color.primary.opacity(0.04))
                                .foregroundColor(transitionDuration == 0.1 ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { transitionDuration = 0.6 }) {
                            Text("Balanced (0.6s)")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(transitionDuration == 0.6 ? Color.accentColor : Color.primary.opacity(0.04))
                                .foregroundColor(transitionDuration == 0.6 ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { transitionDuration = 1.5 }) {
                            Text("Gradual (1.5s)")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(transitionDuration == 1.5 ? Color.accentColor : Color.primary.opacity(0.04))
                                .foregroundColor(transitionDuration == 1.5 ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            
            // Section 2: Shuffle Settings
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 12, weight: .bold))
                            Text("Automatic Wallpaper Rotation")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        Text("Cycles through your library wallpapers automatically")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $shuffleEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                if shuffleEnabled {
                    Divider()
                        .padding(.vertical, 2)
                    
                    HStack {
                        Text("Rotation Interval")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Spacer()
                        Picker("", selection: $shuffleInterval) {
                            Text("1 Minute").tag(60.0)
                            Text("5 Minutes").tag(300.0)
                            Text("15 Minutes").tag(900.0)
                            Text("30 Minutes").tag(1800.0)
                            Text("1 Hour").tag(3600.0)
                        }
                        .frame(width: 150)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            
            // Section 3: General & Startup Options
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "laptopcomputer")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 12, weight: .bold))
                    Text("General Options")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                
                Divider()
                
                HStack {
                    Text("Launch application automatically at login")
                        .font(.system(size: 11, design: .rounded))
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            
            // Footer Quick Links / Reset
            HStack {
                Button(action: {
                    playbackSpeed = 1.0
                    transitionDuration = 0.5
                    shuffleEnabled = false
                    shuffleInterval = 300.0
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                        Text("Open Native Wallpaper Settings")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}
