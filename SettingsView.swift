import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import AVFoundation

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
                                DashboardView(isPlaying: isPlaying, isObscured: isObscured, isLowPower: isLowPower, isManualPaused: isManualPaused)
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
                                    getThumbnailURL: getThumbnailURL,
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
            
            // Sync engine configs but DO NOT re-register the UUID on launch to prevent cache resets
            saveSharedConfig(path: videoPath)
        }
        .onChange(of: videoPath) {
            saveSharedConfig(path: videoPath)
            registerInSystemWallpaperStore(videoPath: videoPath)
        }
        .onChange(of: shuffleEnabled) { _ in
            AppDelegate.shared?.setupShuffleTimer()
        }
        .onChange(of: shuffleInterval) { _ in
            AppDelegate.shared?.setupShuffleTimer()
        }
        .onChange(of: playbackSpeed) { _ in
            NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("wallpaperStatusUpdated"))) { _ in
            refreshEngineStatus()
        }
    }

    private func createPlaceholderImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background Gradient
        let rect = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(starting: NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0),
                                  ending: NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0))
        gradient?.draw(in: rect, angle: 45)
        
        // Central Card
        let cardWidth: CGFloat = 840
        let cardHeight: CGFloat = 520
        let cardRect = NSRect(x: (size.width - cardWidth) / 2,
                              y: (size.height - cardHeight) / 2,
                              width: cardWidth,
                              height: cardHeight)
        
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.03).set()
        path.fill()
        NSColor(white: 1.0, alpha: 0.08).set()
        path.lineWidth = 1.5
        path.stroke()
        
        // Draw Header Title inside Card
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: titleParagraph
        ]
        let titleText = "Welcome to Live Wallpaper"
        let titleRect = NSRect(x: cardRect.minX + 40, y: cardRect.maxY - 100, width: cardRect.width - 80, height: 50)
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Draw Subtitle
        let subParagraph = NSMutableParagraphStyle()
        subParagraph.alignment = .center
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6),
            .paragraphStyle: subParagraph
        ]
        let subText = "Follow these simple steps to activate the live desktop engine:"
        let subRect = NSRect(x: cardRect.minX + 40, y: cardRect.maxY - 140, width: cardRect.width - 80, height: 30)
        subText.draw(in: subRect, withAttributes: subAttributes)
        
        // Draw Step Items (Aligned Left inside Card)
        let stepX = cardRect.minX + 80
        var currentY = cardRect.maxY - 220
        
        let steps = [
            ("1", "Open Wallpaper Settings", "Click 'Open Native Settings...' in this app, or go to System Settings > Wallpaper."),
            ("2", "Find Custom Live Wallpaper", "Scroll down to locate and click the 'Custom Live Wallpaper' category."),
            ("3", "Select Active Wallpaper Feed", "Click on the 'Active Wallpaper Feed' card to activate your video stream.")
        ]
        
        for (num, title, desc) in steps {
            // Draw step number circle
            let circleRect = NSRect(x: stepX, y: currentY - 6, width: 28, height: 28)
            let circlePath = NSBezierPath(ovalIn: circleRect)
            NSColor.systemBlue.withAlphaComponent(0.15).set()
            circlePath.fill()
            NSColor.systemBlue.set()
            circlePath.lineWidth = 1.0
            circlePath.stroke()
            
            // Draw number text
            let numParagraph = NSMutableParagraphStyle()
            numParagraph.alignment = .center
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemBlue,
                .paragraphStyle: numParagraph
            ]
            num.draw(in: NSRect(x: circleRect.minX, y: circleRect.minY + 4, width: circleRect.width, height: 20), withAttributes: numAttr)
            
            // Draw Step Title & Desc
            let itemTitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let itemDescAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.5)
            ]
            
            title.draw(at: NSPoint(x: stepX + 44, y: currentY + 6), withAttributes: itemTitleAttr)
            desc.draw(at: NSPoint(x: stepX + 44, y: currentY - 12), withAttributes: itemDescAttr)
            
            currentY -= 90
        }
        
        // Draw Footer
        let footerParagraph = NSMutableParagraphStyle()
        footerParagraph.alignment = .center
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.3),
            .paragraphStyle: footerParagraph
        ]
        let footerText = "Note: Playback automatically pauses during fullscreen tasks and sleep states."
        let footerRect = NSRect(x: cardRect.minX + 40, y: cardRect.minY + 30, width: cardRect.width - 80, height: 20)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
        
        image.unlockFocus()
        return image
    }

    private func convertMP4ToQuickTimeMOV(sourceURL: URL, destinationURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: sourceURL)
        
        // Strip audio tracks completely before transcoding
        let composition = AVMutableComposition()
        if let videoTrack = asset.tracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
            
            // Remove destination if it exists to avoid collisions
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Directly transcode to HEVC (H.265) using the video-only composition
            self.transcodeToHEVC(asset: composition, destinationURL: destinationURL, completion: completion)
        } else {
            // Fallback if no video tracks found
            try? FileManager.default.removeItem(at: destinationURL)
            self.transcodeToHEVC(asset: asset, destinationURL: destinationURL, completion: completion)
        }
    }
    
    private func transcodeToHEVC(asset: AVAsset, destinationURL: URL, completion: @escaping (Bool) -> Void) {
        // Use HEVC (H.265) preset to satisfy strict macOS secure lock screen requirements
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: "AVAssetExportPresetHEVCDeliverable") else {
            completion(false)
            return
        }
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                print("Successfully transcoded video to native H.265/HEVC QuickTime MOV.")
                completion(true)
            } else {
                print("HEVC transcode failed: \(String(describing: exportSession.error))")
                completion(false)
            }
        }
    }

    private func registerInSystemWallpaperStore(videoPath: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let appSupportDir = libraryDir.appendingPathComponent("Application Support").appendingPathComponent("com.example.LiveWallpaper")
            let wallpaperDir = libraryDir.appendingPathComponent("Application Support").appendingPathComponent("com.apple.wallpaper")
            let aerialsDir = wallpaperDir.appendingPathComponent("aerials")
            let videosDir = aerialsDir.appendingPathComponent("videos")
            let thumbnailsDir = aerialsDir.appendingPathComponent("thumbnails")
            let manifestDir = aerialsDir.appendingPathComponent("manifest")
            let entriesURL = manifestDir.appendingPathComponent("entries.json")
            
            let categoryID = "LW000000-0000-4000-8000-000000000001"
            let subcategoryID = "LW000000-0000-4000-8000-000000000002"
            let assetID = "LW000000-0000-4000-8000-000000000003"
            
            let destinationVideoURL = videosDir.appendingPathComponent("\(assetID).mov")
            let destinationThumbnailURL = thumbnailsDir.appendingPathComponent("\(assetID).png")
            
            do {
                try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)
                
                // 1. Read entries.json
                guard fileManager.fileExists(atPath: entriesURL.path) else { return }
                let entriesData = try Data(contentsOf: entriesURL)
                guard var entriesJson = try JSONSerialization.jsonObject(with: entriesData, options: [.mutableContainers]) as? [String: Any] else { return }
                
                // 2. Cleanup old assets and files
                var assets = entriesJson["assets"] as? [[String: Any]] ?? []
                let ourAssets = assets.filter {
                    let cats = $0["categories"] as? [String] ?? []
                    return cats.contains(categoryID)
                }
                for oldAsset in ourAssets {
                    if let oldID = oldAsset["id"] as? String {
                        let oldVideo = videosDir.appendingPathComponent("\(oldID).mov")
                        let oldThumb = thumbnailsDir.appendingPathComponent("\(oldID).png")
                        try? fileManager.removeItem(at: oldVideo)
                        try? fileManager.removeItem(at: oldThumb)
                    }
                }
                assets.removeAll {
                    let cats = $0["categories"] as? [String] ?? []
                    return cats.contains(categoryID)
                }
                
                let finishRegistration = { (success: Bool) in
                    if !success {
                        print("Failed to prepare video container. Aborting registration.")
                        return
                    }
                    
                    if !videoPath.isEmpty {
                        let sourceURL = URL(fileURLWithPath: videoPath)
                        let asset = AVURLAsset(url: sourceURL)
                        let generator = AVAssetImageGenerator(asset: asset)
                        generator.appliesPreferredTrackTransform = true
                        let time = CMTime(seconds: 0, preferredTimescale: 60)
                        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                                try? pngData.write(to: destinationThumbnailURL)
                            }
                        } else {
                            if let icon = NSApplication.shared.applicationIconImage,
                               let tiff = icon.tiffRepresentation,
                               let bitmap = NSBitmapImageRep(data: tiff),
                               let pngData = bitmap.representation(using: .png, properties: [:]) {
                                try? pngData.write(to: destinationThumbnailURL)
                            }
                        }
                    }
                    
                    // 4. Update Category
                    var categories = entriesJson["categories"] as? [[String: Any]] ?? []
                    categories.removeAll { ($0["id"] as? String) == categoryID }
                    
                    let customCategory: [String: Any] = [
                        "id": categoryID,
                        "localizedDescriptionKey": "Custom Live Wallpaper",
                        "localizedNameKey": "Custom Live Wallpaper",
                        "preferredOrder": 0,
                        "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                        "representativeAssetID": assetID,
                        "subcategories": [
                            [
                                "id": subcategoryID,
                                "localizedDescriptionKey": "Custom Live Wallpaper",
                                "localizedNameKey": "Custom Live Wallpaper",
                                "preferredOrder": 0,
                                "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                                "representativeAssetID": assetID
                            ]
                        ]
                    ]
                    categories.insert(customCategory, at: 0)
                    entriesJson["categories"] = categories
                    
                    // 5. Append Asset
                    let videoURLString = videoPath.isEmpty ? "" : "file://\(destinationVideoURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
                    let customAsset: [String: Any] = [
                        "accessibilityLabel": "Active Wallpaper Feed",
                        "categories": [categoryID],
                        "id": assetID,
                        "includeInShuffle": true,
                        "localizedNameKey": "Active Wallpaper Feed",
                        "pointsOfInterest": ["0": "CUSTOM_LW_0"],
                        "preferredOrder": 0,
                        "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                        "shotID": "CUSTOM_LW",
                        "showInTopLevel": true,
                        "subcategories": [subcategoryID],
                        "url-4K-SDR-240FPS": videoURLString
                    ]
                    assets.append(customAsset)
                    entriesJson["assets"] = assets
                    
                    // 6. Write back
                    do {
                        let updatedData = try JSONSerialization.data(withJSONObject: entriesJson, options: [.prettyPrinted])
                        try updatedData.write(to: entriesURL, options: [.atomic])
                        print("Successfully registered Live Wallpaper in system wallpaper store.")
                        
                        // 7. Force refresh on main thread
                        DispatchQueue.main.async {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                            process.arguments = ["WallpaperAgent"]
                            try? process.run()
                        }
                    } catch {
                        print("Failed to write entries manifest: \(error)")
                    }
                }
                
                // 3. Handle Video & Thumbnail Copy/Creation
                if videoPath.isEmpty {
                    let placeholderImg = self.createPlaceholderImage(size: NSSize(width: 1920, height: 1080))
                    
                    if let tiff = placeholderImg.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        // Write to system thumbnails folder
                        try pngData.write(to: destinationThumbnailURL)
                        
                        // Write to local application folder to use as desktop wallpaper
                        let localPlaceholderURL = appSupportDir.appendingPathComponent("placeholder_instructions.png")
                        try pngData.write(to: localPlaceholderURL)
                        
                        // Force set as desktop image immediately for all screens
                        DispatchQueue.main.async {
                            let workspace = NSWorkspace.shared
                            let screens = NSScreen.screens
                            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                                .allowClipping: true
                            ]
                            for screen in screens {
                                try? workspace.setDesktopImageURL(localPlaceholderURL, for: screen, options: options)
                            }
                        }
                    }
                    
                    finishRegistration(true)
                } else {
                    // Re-mux video to native QuickTime MOV asynchronously
                    let sourceURL = URL(fileURLWithPath: videoPath)
                    self.convertMP4ToQuickTimeMOV(sourceURL: sourceURL, destinationURL: destinationVideoURL) { ok in
                        if ok {
                            finishRegistration(true)
                        } else {
                            // Fallback to direct raw copy if transcode fails entirely
                            print("Re-muxing failed completely. Falling back to direct raw copy...")
                            do {
                                try fileManager.copyItem(at: sourceURL, to: destinationVideoURL)
                                finishRegistration(true)
                            } catch {
                                print("Raw fallback copy also failed: \(error)")
                                finishRegistration(false)
                            }
                        }
                    }
                }
            } catch {
                print("Failed to register wallpaper in system store: \(error)")
            }
        }
    }

    private func saveSharedConfig(path: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configURL = homeDir.appendingPathComponent(".live_wallpaper_config.plist")
        let dict: [String: Any] = [
            "videoPath": path,
            "isMuted": true
        ]
        (dict as NSDictionary).write(to: configURL, atomically: true)
    }

    private func refreshEngineStatus() {
        if let appDelegate = AppDelegate.shared {
            // Read aggregate states from windows
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
                return ext == "mp4" || ext == "mov"
            }
        } catch {
            print("Failed to load imported wallpapers: \(error)")
        }
    }
    
    private func getThumbnailURL(for videoURL: URL) -> URL {
        let fileManager = FileManager.default
        let thumbnailsDir = videoURL.deletingLastPathComponent().appendingPathComponent(".thumbnails")
        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)
        
        let thumbnailURL = thumbnailsDir.appendingPathComponent(videoURL.deletingPathExtension().lastPathComponent + ".png")
        
        if !fileManager.fileExists(atPath: thumbnailURL.path) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 60)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: thumbnailURL)
                }
            }
        }
        
        return thumbnailURL
    }

    private func ensureCompatibleVideo(at sourcePath: String, completion: @escaping (String) -> Void) {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 60)
        
        // Test if AVFoundation can decode the first frame
        if let _ = try? generator.copyCGImage(at: time, actualTime: nil) {
            completion(sourcePath)
            return
        }
        
        // Video is incompatible. Try to transcode using ffmpeg if available.
        let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
        let fm = FileManager.default
        guard fm.fileExists(atPath: ffmpegPath) else {
            completion(sourcePath)
            return
        }
        
        let tempDir = fm.temporaryDirectory
        let tempOutputURL = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-i", sourcePath,
            "-c:v", "libx264",
            "-an",
            tempOutputURL.path
        ]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 && fm.fileExists(atPath: tempOutputURL.path) {
                    DispatchQueue.main.async {
                        completion(tempOutputURL.path)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(sourcePath)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(sourcePath)
                }
            }
        }
    }

    private func copyToAppSupportAndRegister(sourcePath: String) {
        guard !sourcePath.isEmpty else {
            removeSelectedWallpaper()
            return
        }
        
        self.ensureCompatibleVideo(at: sourcePath) { compatiblePath in
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
                registerInSystemWallpaperStore(videoPath: destinationURL.path)
                NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
                loadImportedWallpapers()
            } catch {
                print("Failed to copy video to Library storage: \(error)")
            }
        }
    }
    
    private func removeSelectedWallpaper() {
        self.videoPath = ""
        registerInSystemWallpaperStore(videoPath: "")
        NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
    }
    
    private func selectWallpaper(url: URL) {
        self.videoPath = url.path
        registerInSystemWallpaperStore(videoPath: url.path)
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

    private func locateYTDLP() -> String? {
        let paths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/yt-dlp"
        ]
        let fm = FileManager.default
        for path in paths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yt-dlp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return path
            }
        }
        return nil
    }

    private func selectNewestWallpaper(associatedURL: String? = nil) {
        let fileManager = FileManager.default
        let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                            .appendingPathComponent("com.example.LiveWallpaper")
                                            .appendingPathComponent("Library")
        do {
            let files = try fileManager.contentsOfDirectory(at: appSupportLibraryDir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            let sortedFiles = try files.map { url -> (URL, Date) in
                let values = try url.resourceValues(forKeys: [.creationDateKey])
                return (url, values.creationDate ?? Date.distantPast)
            }.sorted(by: { $0.1 > $1.1 })
            
            if let newest = sortedFiles.first?.0 {
                self.videoPath = newest.path
                
                if let urlStr = associatedURL {
                    var dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
                    dict[newest.lastPathComponent] = urlStr
                    UserDefaults.standard.set(dict, forKey: "youtubeURLs")
                }
                
                registerInSystemWallpaperStore(videoPath: newest.path)
                NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
                loadImportedWallpapers()
            }
        } catch {
            print("Failed to find newest wallpaper: \(error)")
        }
    }

    private func downloadYouTubeVideo(urlStr: String) {
        guard let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(),
              host.contains("youtube.com") || host.contains("youtu.be") else {
            self.ytDownloadError = "Invalid YouTube URL"
            return
        }
        
        guard let ytDlpPath = locateYTDLP() else {
            self.ytDownloadError = "yt-dlp not found. Please install it via Homebrew: brew install yt-dlp"
            return
        }
        
        self.isDownloadingYT = true
        self.ytDownloadError = ""
        self.ytDownloadProgress = "0%"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                                .appendingPathComponent("com.example.LiveWallpaper")
                                                .appendingPathComponent("Library")
            
            do {
                try fileManager.createDirectory(at: appSupportLibraryDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    self.isDownloadingYT = false
                    self.ytDownloadProgress = ""
                    self.ytDownloadError = "Failed to create storage directory"
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = [
                "-f", "bestvideo[vcodec^=avc1]/bestvideo",
                "-P", appSupportLibraryDir.path,
                urlStr
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            let fileHandle = pipe.fileHandleForReading
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    if let progressRange = output.range(of: "\\b\\d+(\\.\\d+)?%", options: .regularExpression) {
                        let percent = String(output[progressRange])
                        DispatchQueue.main.async {
                            self.ytDownloadProgress = percent
                        }
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                fileHandle.readabilityHandler = nil
                
                DispatchQueue.main.async {
                    self.isDownloadingYT = false
                    self.ytDownloadProgress = ""
                    if process.terminationStatus == 0 {
                        let savedURL = urlStr
                        self.ytURL = ""
                        self.selectNewestWallpaper(associatedURL: savedURL)
                    } else {
                        self.ytDownloadError = "Download failed (code \(process.terminationStatus))"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    self.isDownloadingYT = false
                    self.ytDownloadProgress = ""
                    self.ytDownloadError = error.localizedDescription
                }
            }
        }
    }
}

// Custom hoverable Sidebar Button
struct TabButton: View {
    let title: String
    let icon: String
    @Binding var selectedTab: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            selectedTab = title
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: selectedTab == title ? .semibold : .medium))
                    .frame(width: 16)
                    .foregroundColor(selectedTab == title ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == title ? .semibold : .medium, design: .rounded))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == title ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .foregroundColor(selectedTab == title ? .accentColor : .primary.opacity(0.85))
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Engine Dashboard tab
struct WaveBarView: View {
    let isPlaying: Bool
    let delay: Double
    @State private var scale: CGFloat = 0.2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(isPlaying ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 3, height: 18)
            .scaleEffect(y: isPlaying ? scale : 0.2, anchor: .center)
            .onAppear {
                if isPlaying {
                    withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                        scale = 1.0
                    }
                }
            }
            .onChange(of: isPlaying) { playing in
                if playing {
                    withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                        scale = 1.0
                    }
                } else {
                    scale = 0.2
                }
            }
    }
}

struct ScreenVisualizerView: View {
    var isPlaying: Bool
    var activeThumbnailURL: URL?
    
    var body: some View {
        let screens = NSScreen.screens
        let frames = screens.map { $0.frame }
        let minX = frames.map { $0.minX }.min() ?? 0
        let minY = frames.map { $0.minY }.min() ?? 0
        let maxX = frames.map { $0.maxX }.max() ?? 1
        let maxY = frames.map { $0.maxY }.max() ?? 1
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY
        
        let containerWidth: CGFloat = 160
        let containerHeight: CGFloat = 80
        let scale = min(containerWidth / totalWidth, containerHeight / totalHeight) * 0.8
        
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
            
            ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                let frame = screen.frame
                let w = frame.width * scale
                let h = frame.height * scale
                let x = (frame.minX - minX + (frame.width - totalWidth) / 2) * scale
                let y = -(frame.minY - minY + (frame.height - totalHeight) / 2) * scale
                
                VStack(spacing: 1) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.black)
                            .frame(width: w, height: h)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Group {
                            if isPlaying {
                                if let thumbURL = activeThumbnailURL, let nsImage = NSImage(contentsOf: thumbURL) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: w - 2, height: h - 2)
                        .cornerRadius(3)
                        .clipped()
                        
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(isPlaying ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                            .cornerRadius(2)
                    }
                    
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: max(4, w * 0.15), height: 4)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: max(8, w * 0.35), height: 1)
                }
                .offset(x: x, y: y)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
    }
}

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
            VStack(alignment: .leading, spacing: 10) {
                Text("CURRENT WALLPAPER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                if !videoPath.isEmpty {
                    HStack(spacing: 12) {
                        // Thumbnail Preview
                        Group {
                            if let thumbURL = activeThumbnailURL, let nsImage = NSImage(contentsOf: thumbURL) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    Color.primary.opacity(0.03)
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.secondary.opacity(0.4))
                                }
                            }
                        }
                        .frame(width: 120, height: 68)
                        .cornerRadius(6)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        
                        // Metadata Info
                        VStack(alignment: .leading, spacing: 3) {
                            Text(URL(fileURLWithPath: videoPath).lastPathComponent)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text("HEVC Video")
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(4)
                                
                                if !fileSizeString.isEmpty {
                                    Text(fileSizeString)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Actions
                            HStack(spacing: 8) {
                                Button(action: {
                                    NSWorkspace.shared.selectFile(videoPath, inFileViewerRootedAtPath: "")
                                }) {
                                    Label("Reveal in Finder", systemImage: "folder.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                if let ytURLStr = youtubeURL, let ytURL = URL(string: ytURLStr) {
                                    Button(action: {
                                        NSWorkspace.shared.open(ytURL)
                                    }) {
                                        Label("Visit Source", systemImage: "safari.fill")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .frame(height: 68)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No Active Wallpaper")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Import or select a wallpaper from the Wallpaper library tab.")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
            }
            
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
                            NotificationCenter.default.post(name: Notification.Name("triggerWallpaperShuffle"), object: nil)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("DIAGNOSTICS & METRICS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    let columns = [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 8) {
                        MiniDiagCard(title: "Obscuration", value: isObscured ? "Obscured" : "Visible", statusColor: isObscured ? .orange : .green)
                        MiniDiagCard(title: "Power Mode", value: isLowPower ? "Eco Mode" : "Normal", statusColor: isLowPower ? .orange : .blue)
                        MiniDiagCard(title: "Target FPS", value: isPlaying ? "60 FPS" : "0 FPS", statusColor: isPlaying ? .green : .secondary)
                        MiniDiagCard(title: "Decoder", value: "Hardware HEVC", statusColor: .green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct MiniDiagCard: View {
    let title: String
    let value: String
    let statusColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

// Wallpaper Library panel
struct WallpaperSettingsView: View {
    @Binding var videoPath: String
    @Binding var launchAtLogin: Bool
    @Binding var isDraggingOver: Bool
    let selectVideoFile: () -> Void
    let toggleLaunchAtLogin: (Bool) -> Void
    let removeSelectedWallpaper: () -> Void
    let onVideoDropped: (String) -> Void
    
    let importedWallpapers: [URL]
    let selectWallpaper: (URL) -> Void
    let deleteWallpaper: (URL) -> Void
    let getThumbnailURL: (URL) -> URL
    
    @Binding var ytURL: String
    @Binding var isDownloadingYT: Bool
    @Binding var ytDownloadError: String
    @Binding var ytDownloadProgress: String
    let downloadYouTubeVideo: (String) -> Void
    
    @State private var showYTDownloadPopover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row with Plus Button
            HStack {
                Text("Wallpaper Library")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Spacer()
                
                Menu {
                    Button(action: selectVideoFile) {
                        Label("Import Video File...", systemImage: "plus.viewfinder")
                    }
                    Button(action: { showYTDownloadPopover = true }) {
                        Label("Download from YouTube...", systemImage: "play.rectangle.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
                .popover(isPresented: $showYTDownloadPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            Text("Download YouTube Wallpaper")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        
                        Text("Paste a YouTube link below. The video will be downloaded, optimized, and saved directly to your wallpaper library.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(spacing: 8) {
                            TextField("https://www.youtube.com/watch?v=...", text: $ytURL)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isDownloadingYT)
                                .font(.system(size: 11))
                            
                            if isDownloadingYT {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Downloading...")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(ytDownloadProgress)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                    }
                                    
                                    let cleanPct = ytDownloadProgress.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                                    if let pct = Double(cleanPct) {
                                        ProgressView(value: pct, total: 100)
                                            .progressViewStyle(.linear)
                                    } else {
                                        ProgressView()
                                            .progressViewStyle(.linear)
                                    }
                                }
                                .padding(.top, 4)
                            } else {
                                Button(action: {
                                    downloadYouTubeVideo(ytURL)
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Start Download")
                                        Spacer()
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(ytURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        
                        if !ytDownloadError.isEmpty {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                Text(ytDownloadError)
                                    .font(.system(size: 9))
                                    .foregroundColor(.red)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(14)
                    .frame(width: 290)
                }
            }
            
            // Library list
            if importedWallpapers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Library is empty. Click + to import or download.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(Color.primary.opacity(0.015))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
            } else {
                ScrollView {
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(importedWallpapers, id: \.self) { url in
                            WallpaperLibraryCard(
                                url: url,
                                isActive: videoPath == url.path,
                                onApply: { selectWallpaper(url) },
                                onDelete: { deleteWallpaper(url) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.isFileURL, url.pathExtension.lowercased() == "mp4" {
                    DispatchQueue.main.async {
                        onVideoDropped(url.path)
                    }
                }
            }
            return true
        }
    }
}

private final class ThumbnailCache {
    static let shared = NSCache<NSURL, NSImage>()
}

struct WallpaperLibraryCard: View {
    let url: URL
    let isActive: Bool
    let onApply: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage? = nil
    @State private var fileSizeString: String = ""
    
    private var youtubeURL: String? {
        let dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
        return dict[url.lastPathComponent]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 94)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    ZStack {
                        Color.primary.opacity(0.03)
                        Image(systemName: "video.fill")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 16))
                    }
                    .frame(height: 94)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                }
                
                // Hover Actions Overlay
                if isHovered || isActive {
                    Color.black.opacity(isActive ? 0.45 : 0.25)
                        .cornerRadius(8)
                    
                    VStack {
                        HStack {
                            if isActive {
                                Text("Active")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            Spacer()
                            
                            if let ytURLStr = youtubeURL, let ytURL = URL(string: ytURLStr) {
                                Button(action: {
                                    NSWorkspace.shared.open(ytURL)
                                }) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Open YouTube link")
                            }
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(6)
                        
                        Spacer()
                        
                        if !isActive {
                            Button(action: onApply) {
                                Text("Apply Wallpaper")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .shadow(color: .black.opacity(0.15), radius: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .frame(height: 94)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.green : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05)), lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: isActive ? Color.green.opacity(0.2) : (isHovered ? Color.black.opacity(0.08) : Color.clear), radius: isActive ? 6 : 3, x: 0, y: isActive ? 3 : 1)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Use a non-empty space placeholder to lock layout height and prevent shifts
                Text(fileSizeString.isEmpty ? " " : fileSizeString)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadMetadataAndThumbnail()
        }
        .onChange(of: url) { _ in
            loadMetadataAndThumbnail()
        }
    }
    
    private func loadMetadataAndThumbnail() {
        let targetURL = url
        
        // 1. Check static in-memory cache first for instant lag-free rendering
        if let cachedImage = ThumbnailCache.shared.object(forKey: targetURL as NSURL) {
            self.thumbnailImage = cachedImage
            
            // Still fetch size on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                let sizeStr = self.calculateSize(for: targetURL)
                DispatchQueue.main.async {
                    self.fileSizeString = sizeStr
                }
            }
            return
        }
        
        // 2. Offload I/O, file check, and image decoding completely to concurrent background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let sizeStr = self.calculateSize(for: targetURL)
            let fileManager = FileManager.default
            let thumbnailsDir = targetURL.deletingLastPathComponent().appendingPathComponent(".thumbnails")
            let thumbnailURL = thumbnailsDir.appendingPathComponent(targetURL.deletingPathExtension().lastPathComponent + ".png")
            
            if !fileManager.fileExists(atPath: thumbnailURL.path) {
                try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)
                
                let asset = AVURLAsset(url: targetURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 0, preferredTimescale: 60)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: thumbnailURL)
                    }
                }
            }
            
            let loadedImage = NSImage(contentsOf: thumbnailURL)
            
            DispatchQueue.main.async {
                if let image = loadedImage {
                    ThumbnailCache.shared.setObject(image, forKey: targetURL as NSURL)
                    self.thumbnailImage = image
                }
                self.fileSizeString = sizeStr
            }
        }
    }
    
    private func calculateSize(for targetURL: URL) -> String {
        var sizeStr = ""
        if let values = try? targetURL.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .file
            sizeStr = formatter.string(fromByteCount: Int64(size))
        }
        return sizeStr
    }
}

// Engine / Playback Settings panel
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
                        .onChange(of: launchAtLogin) { _ in
                            toggleLaunchAtLogin(launchAtLogin)
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

// About tab panel
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if let iconImage = NSApplication.shared.applicationIconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 4) {
                Text("Live Wallpaper")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                Text("Version 1.1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("A performance-optimized macOS live video wallpaper engine that pauses during fullscreen tasks and sleep states.")
                .font(.system(size: 11, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Divider()
                .padding(.horizontal, 40)
            
            Text("© 2026 Live Wallpaper Team. All rights reserved.")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))
            
            Spacer()
        }
    }
}

// Custom UI helper for drag & drop visual feedback
struct ZCornerRectangle<Content: View>: View {
    var isDragging: Bool
    var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
                .background(isDragging ? Color.accentColor.opacity(0.04) : Color.primary.opacity(0.01))
                .cornerRadius(12)
            
            content()
        }
    }
}

extension Notification.Name {
    static let wallpaperVideoChanged = Notification.Name("wallpaperVideoChanged")
    static let wallpaperMuteChanged = Notification.Name("wallpaperMuteChanged")
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

