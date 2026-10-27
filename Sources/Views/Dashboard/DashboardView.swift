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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Active Wallpaper Section
                ActiveWallpaperHeroCard(
                    videoPath: videoPath,
                    activeThumbnailURL: activeThumbnailURL,
                    fileSizeString: fileSizeString,
                    youtubeURL: youtubeURL,
                    isPlaying: isPlaying
                )
                
                Divider()
                
                // Displays Visualization Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Connected Displays")
                            .font(.headline)
                        Spacer()
                        let screens = NSScreen.screens
                        Text("\(screens.count) Display\(screens.count == 1 ? "" : "s") Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Spacer()
                        ScreenVisualizerView(isPlaying: isPlaying, activeThumbnailURL: activeThumbnailURL)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Diagnostics Section
                DiagnosticsMetricsGrid(
                    isPlaying: isPlaying,
                    isObscured: isObscured,
                    isLowPower: isLowPower
                )
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("manualTogglePlayback"), object: nil)
                }) {
                    Label(
                        isManualPaused ? "Resume Engine" : "Pause Engine",
                        systemImage: isManualPaused ? "play.fill" : "pause.fill"
                    )
                }
                .keyboardShortcut(.space, modifiers: [])
                .help(isManualPaused ? "Resume video rendering (Space)" : "Pause video rendering (Space)")
                
                Button(action: {
                    NotificationCenter.default.post(name: .triggerWallpaperShuffle, object: nil)
                }) {
                    Label("Shuffle Wallpaper", systemImage: "shuffle")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Shuffle to another wallpaper (Cmd+R)")
                
                Menu {
                    Button(action: {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                            process.arguments = ["WallpaperAgent"]
                            try? process.run()
                        }
                    }) {
                        Label("Restart WallpaperAgent", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
