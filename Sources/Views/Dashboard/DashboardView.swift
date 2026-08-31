import SwiftUI
import AppKit

struct DashboardView: View {
    var isPlaying: Bool
    var isObscured: Bool
    var isLowPower: Bool
    var isManualPaused: Bool
    
    @AppStorage("videoPath") private var videoPath: String = ""
    
    private var activeThumbnailURL: URL? {
        guard !videoPath.isEmpty else { return nil }
        let videoURL = URL(fileURLWithPath: videoPath)
        let thumbnailsDir = videoURL.deletingLastPathComponent().appendingPathComponent(".thumbnails")
        let thumbnailURL = thumbnailsDir.appendingPathComponent(videoURL.deletingPathExtension().lastPathComponent + ".png")
        return FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL : nil
    }
    
    private var fileSizeString: String {
        guard !videoPath.isEmpty else { return "" }
        let fm = FileManager.default
        if fm.fileExists(atPath: videoPath),
           let attribs = try? fm.attributesOfItem(atPath: videoPath),
           let size = attribs[.size] as? UInt64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(size))
        }
        return ""
    }
    
    private var youtubeURL: String? {
        guard !videoPath.isEmpty else { return nil }
        let filename = URL(fileURLWithPath: videoPath).lastPathComponent
        let dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
        return dict[filename]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section 1: Engine Status Banner
            HStack(spacing: 14) {
                // Pulse Indicator & Title
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .fill(isPlaying ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                            .scaleEffect(isPlaying ? 1.2 : 1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPlaying ? "Wallpaper Engine Active" : "Wallpaper Engine Suspended")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        
                        let screens = NSScreen.screens
                        Text("\(screens.count) monitor\(screens.count > 1 ? "s" : "") detected")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Audio-style Wave Visualizer
                HStack(spacing: 2) {
                    WaveBarView(isPlaying: isPlaying, delay: 0.0)
                    WaveBarView(isPlaying: isPlaying, delay: 0.1)
                    WaveBarView(isPlaying: isPlaying, delay: 0.2)
                    WaveBarView(isPlaying: isPlaying, delay: 0.3)
                    WaveBarView(isPlaying: isPlaying, delay: 0.4)
                }
                .padding(.trailing, 8)
                
                // Mini Displays Visualizer
                ScreenVisualizerView(isPlaying: isPlaying, activeThumbnailURL: activeThumbnailURL)
            }
            .padding(12)
            .background(.thinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isPlaying ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
            )
            
            // Section 2: Active Wallpaper Hero Card
            ActiveWallpaperHeroCard(
                videoPath: videoPath,
                activeThumbnailURL: activeThumbnailURL,
                fileSizeString: fileSizeString,
                youtubeURL: youtubeURL
            )
            
            // Section 3: Controls and Status Grid
            HStack(alignment: .top, spacing: 14) {
                // Controls Column
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK CONTROLS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        // Pause/Resume
                        Button(action: {
                            NotificationCenter.default.post(name: Notification.Name("manualTogglePlayback"), object: nil)
                        }) {
                            HStack {
                                Image(systemName: isManualPaused ? "play.fill" : "pause.fill")
                                Text(isManualPaused ? "Resume Engine" : "Pause Engine")
                                Spacer()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(isManualPaused ? Color.green : Color.accentColor)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Shuffle Now
                        Button(action: {
                            NotificationCenter.default.post(name: .triggerWallpaperShuffle, object: nil)
                        }) {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("Shuffle Wallpapers")
                                Spacer()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Restart Agent
                        Button(action: {
                            DispatchQueue.global(qos: .userInitiated).async {
                                let process = Process()
                                process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                                process.arguments = ["WallpaperAgent"]
                                try? process.run()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Restart Agent")
                                Spacer()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Diagnostics Column
                DiagnosticsMetricsGrid(
                    isPlaying: isPlaying,
                    isObscured: isObscured,
                    isLowPower: isLowPower
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}
