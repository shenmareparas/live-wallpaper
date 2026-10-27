import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement

struct SettingsView: View {
    @AppStorage("videoPath") private var videoPath: String = ""
    
    // Core Engine Configurations
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("transitionDuration") private var transitionDuration: Double = 0.5
    @AppStorage("shuffleEnabled") private var shuffleEnabled: Bool = false
    @AppStorage("shuffleInterval") private var shuffleInterval: Double = 300.0 // 5 minutes default
    
    @State private var launchAtLogin: Bool = false
    @State private var isDraggingOver = false
    @State private var selectedTab: String = "Dashboard"

    // Live engine states
    @State private var isPlaying: Bool = true
    @State private var isObscured: Bool = false
    @State private var isLowPower: Bool = false
    @State private var isManualPaused: Bool = false
    
    // Library collection
    @State private var importedWallpapers: [URL] = []
    
    // YouTube Downloader states
    @State private var ytURL: String = ""
    @State private var isDownloadingYT: Bool = false
    @State private var ytDownloadError: String = ""
    @State private var ytDownloadProgress: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            VStack(alignment: .leading, spacing: 6) {
                // App Title
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("Live Wallpaper")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.top, 48)
                .padding(.bottom, 16)
                
                TabButton(title: "Dashboard", icon: "square.grid.2x2.fill", selectedTab: $selectedTab)
                TabButton(title: "Wallpaper", icon: "photo.fill", selectedTab: $selectedTab)
                TabButton(title: "Settings", icon: "gearshape.fill", selectedTab: $selectedTab)
                
                Spacer()
                
                TabButton(title: "About", icon: "info.circle.fill", selectedTab: $selectedTab)
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 12)
            .frame(width: 175)
            .frame(maxHeight: .infinity)
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            
            // Content Pane
            ZStack {
                VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if selectedTab == "Dashboard" {
                                DashboardView(
                                    isPlaying: isPlaying,
                                    isObscured: isObscured,
                                    isLowPower: isLowPower,
                                    isManualPaused: isManualPaused
                                )
                            } else if selectedTab == "Wallpaper" {
                                WallpaperSettingsView(
                                    videoPath: $videoPath,
                                    launchAtLogin: $launchAtLogin,
                                    isDraggingOver: $isDraggingOver,
                                    selectVideoFile: selectVideoFile,
                                    toggleLaunchAtLogin: toggleLaunchAtLogin,
                                    removeSelectedWallpaper: removeSelectedWallpaper,
                                    onVideoDropped: copyToAppSupportAndRegister,
                                    importedWallpapers: importedWallpapers,
                                    selectWallpaper: selectWallpaper,
                                    deleteWallpaper: deleteWallpaper,
                                    getThumbnailURL: { ThumbnailService.shared.getThumbnailURL(for: $0) },
                                    ytURL: $ytURL,
                                    isDownloadingYT: $isDownloadingYT,
                                    ytDownloadError: $ytDownloadError,
                                    ytDownloadProgress: $ytDownloadProgress,
                                    downloadYouTubeVideo: downloadYouTubeVideo
                                )
                            } else if selectedTab == "Settings" {
                                EngineSettingsView(
                                    playbackSpeed: $playbackSpeed,
                                    transitionDuration: $transitionDuration,
                                    shuffleEnabled: $shuffleEnabled,
                                    shuffleInterval: $shuffleInterval,
                                    launchAtLogin: $launchAtLogin,
                                    toggleLaunchAtLogin: toggleLaunchAtLogin
                                )
                            } else {
                                AboutView()
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 760, height: 540)
        .ignoresSafeArea()
        .onAppear {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
            refreshEngineStatus()
            loadImportedWallpapers()
            WallpaperStoreService.shared.saveSharedConfig(path: videoPath)
        }
        .onChange(of: videoPath) {
            WallpaperStoreService.shared.saveSharedConfig(path: videoPath)
            WallpaperStoreService.shared.registerInSystemWallpaperStore(videoPath: videoPath)
        }
        .onChange(of: shuffleEnabled) {
            AppDelegate.shared?.setupShuffleTimer()
        }
        .onChange(of: shuffleInterval) {
            AppDelegate.shared?.setupShuffleTimer()
        }
        .onChange(of: playbackSpeed) {
            NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperStatusUpdated)) { _ in
            refreshEngineStatus()
        }
    }

    private func refreshEngineStatus() {
        if let appDelegate = AppDelegate.shared {
            let windows = appDelegate.wallpaperWindows.values
            self.isPlaying = windows.contains { $0.isPlaying }
            self.isObscured = windows.allSatisfy { $0.isObscuredState }
            self.isLowPower = windows.contains { $0.isLowPowerState }
            self.isManualPaused = windows.contains { $0.isManualPausedState }
        }
    }
    
    private func loadImportedWallpapers() {
        let fileManager = FileManager.default
        let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                            .appendingPathComponent("com.example.LiveWallpaper")
                                            .appendingPathComponent("Library")
        
        do {
            try fileManager.createDirectory(at: appSupportLibraryDir, withIntermediateDirectories: true, attributes: nil)
            let files = try fileManager.contentsOfDirectory(at: appSupportLibraryDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            self.importedWallpapers = files.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext)
            }
        } catch {
            print("Failed to load imported wallpapers: \(error)")
        }
    }

    private func copyToAppSupportAndRegister(sourcePath: String) {
        guard !sourcePath.isEmpty else {
            removeSelectedWallpaper()
            return
        }
        
        VideoTranscodeService.shared.ensureCompatibleVideo(at: sourcePath) { compatiblePath in
            let fileManager = FileManager.default
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                                .appendingPathComponent("com.example.LiveWallpaper")
                                                .appendingPathComponent("Library")
            
            let sourceURL = URL(fileURLWithPath: compatiblePath)
            let originalName = URL(fileURLWithPath: sourcePath).lastPathComponent
            let destinationURL = appSupportLibraryDir.appendingPathComponent(originalName)
            
            do {
                try fileManager.createDirectory(at: appSupportLibraryDir, withIntermediateDirectories: true, attributes: nil)
                
                // Copy to storage if not already there
                if sourceURL.deletingLastPathComponent().path != appSupportLibraryDir.path {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
                
                // If it was a temp file, clean it up
                if compatiblePath != sourcePath {
                    try? fileManager.removeItem(at: sourceURL)
                }
                
                self.videoPath = destinationURL.path
                WallpaperStoreService.shared.registerInSystemWallpaperStore(videoPath: destinationURL.path)
                NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
                loadImportedWallpapers()
            } catch {
                print("Failed to copy video to Library storage: \(error)")
            }
        }
    }
    
    private func removeSelectedWallpaper() {
        self.videoPath = ""
        WallpaperStoreService.shared.registerInSystemWallpaperStore(videoPath: "")
        NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
    }
    
    private func selectWallpaper(url: URL) {
        self.videoPath = url.path
        WallpaperStoreService.shared.registerInSystemWallpaperStore(videoPath: url.path)
        NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
    }
    
    private func deleteWallpaper(url: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: url)
            
            // Delete associated thumbnail
            let thumbnailsDir = url.deletingLastPathComponent().appendingPathComponent(".thumbnails")
            let thumbnailURL = thumbnailsDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".png")
            try? fileManager.removeItem(at: thumbnailURL)
            
            // Delete associated YouTube URL mapping
            var dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
            dict.removeValue(forKey: url.lastPathComponent)
            UserDefaults.standard.set(dict, forKey: "youtubeURLs")
            
            if self.videoPath == url.path {
                removeSelectedWallpaper()
            }
            loadImportedWallpapers()
        } catch {
            print("Failed to delete wallpaper: \(error)")
        }
    }

    private func selectVideoFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.mpeg4Movie, UTType.movie]

        if panel.runModal() == .OK {
            if let url = panel.url {
                copyToAppSupportAndRegister(sourcePath: url.path)
            }
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        if enable {
            do {
                try service.register()
                print("Registered Live Wallpaper for launch at login.")
            } catch {
                print("Failed to register SMAppService: \(error.localizedDescription)")
            }
        } else {
            do {
                try service.unregister()
                print("Unregistered Live Wallpaper from launch at login.")
            } catch {
                print("Failed to unregister SMAppService: \(error.localizedDescription)")
            }
        }
    }

    private func downloadYouTubeVideo(urlStr: String) {
        self.isDownloadingYT = true
        self.ytDownloadError = ""
        self.ytDownloadProgress = "0%"
        
        YouTubeDownloaderService.shared.download(
            urlStr: urlStr,
            onProgress: { progress in
                self.ytDownloadProgress = progress
            },
            onCompletion: { result in
                self.isDownloadingYT = false
                self.ytDownloadProgress = ""
                switch result {
                case .success(let fileURL):
                    self.ytURL = ""
                    self.selectWallpaper(url: fileURL)
                    self.loadImportedWallpapers()
                case .failure(let error):
                    self.ytDownloadError = error.localizedDescription
                }
            }
        )
    }
}
