import AppKit
import AVFoundation

class WallpaperWindow: NSWindow {
    private var targetScreen: NSScreen
    
    // Track current active player & layer
    private var currentPlayer: AVQueuePlayer?
    private var currentLooper: AVPlayerLooper?
    private var currentPlayerLayer: AVPlayerLayer?
    
    private var isObscured = false
    private var isLowPowerModeActive = ProcessInfo.processInfo.isLowPowerModeEnabled
    
    private var timer: Timer?
    var isManualPaused = false
    
    /// Set to true once tearDown() has been called. Guards against CATransaction
    /// completion blocks firing after the player has already been destroyed.
    private var isTornDown = false

    /// Holds the first-frame PNG shown during the image→video transition on unlock.
    private var thumbnailLayer: CALayer?

    var isPlaying: Bool {
        guard let player = currentPlayer else { return false }
        return player.rate != 0
    }
    var isObscuredState: Bool { return isObscured }
    var isLowPowerState: Bool { return isLowPowerModeActive }
    var isManualPausedState: Bool { return isManualPaused }
    
    deinit {
        tearDown()
    }

    /// Fully releases all AVPlayer / AVPlayerLayer state and hardware VideoToolbox decoders.
    func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true

        timer?.invalidate()
        timer = nil

        // Remove thumbnail overlay immediately so it doesn't linger
        thumbnailLayer?.removeFromSuperlayer()
        thumbnailLayer = nil

        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)

        // Fully release hardware decoders in the correct order:
        // 1. Pause and cancel any queued decode work
        currentPlayer?.pause()
        currentPlayer?.cancelPendingPrerolls()
        // 2. Sever the layer → player connection so VideoToolbox releases the surface
        currentPlayerLayer?.player = nil
        // 3. Unload the media item from the decode pipeline
        currentPlayer?.replaceCurrentItem(with: nil)
        // 4. Remove the layer from the hierarchy
        currentPlayerLayer?.removeFromSuperlayer()
        // 5. Nil out all strong references so ARC can free them
        currentPlayer = nil
        currentLooper = nil
        currentPlayerLayer = nil

        print("WallpaperWindow: Fully torn down player and all decoders on screen \(targetScreen.localizedName).")
    }

    init(screen: NSScreen, fadeIn: Bool = false) {
        self.targetScreen = screen
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.canHide = false
        self.title = "Live Wallpaper Window - \(screen.localizedName)"
        self.isOpaque = false
        self.backgroundColor = .black
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .canJoinAllApplications]
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        
        if fadeIn { self.alphaValue = 0.0 }
        
        setupObservers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupPlayer(frame: screen.frame)
            self.checkOcclusion()
            
            if fadeIn {
                self.addThumbnailOverlay(frame: screen.frame)
                
                if self.thumbnailLayer != nil {
                    self.alphaValue = 1.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.fadeThumbnailOut(duration: 0.7)
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSAnimationContext.runAnimationGroup { ctx in
                            ctx.duration = 0.55
                            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            self.animator().alphaValue = 1.0
                        }
                    }
                }
            }
        }
    }

    // MARK: - Thumbnail Image → Video Transition

    private func addThumbnailOverlay(frame: NSRect) {
        guard !isTornDown else { return }
        let fileManager = FileManager.default
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let thumbnailURL = cachesURL.appendingPathComponent("live_wallpaper_fallback.png")
        guard fileManager.fileExists(atPath: thumbnailURL.path),
              let image = NSImage(contentsOf: thumbnailURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        let layer = CALayer()
        layer.frame = NSRect(origin: .zero, size: frame.size)
        layer.contents = cgImage
        layer.contentsGravity = .resizeAspectFill
        layer.opacity = 1.0
        self.contentView?.layer?.addSublayer(layer)
        self.thumbnailLayer = layer
    }

    private func fadeThumbnailOut(duration: TimeInterval) {
        guard !isTornDown, let layer = thumbnailLayer else { return }

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue   = 0.0
        fadeOut.duration  = duration
        fadeOut.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self, !self.isTornDown else { return }
            self.thumbnailLayer?.removeFromSuperlayer()
            self.thumbnailLayer = nil
        }
        layer.add(fadeOut, forKey: "thumbnailFadeOut")
        layer.opacity = 0.0
        CATransaction.commit()
    }

    private func setupPlayer(frame: NSRect) {
        var videoURL: URL?
        
        // Load custom video if set
        if let customPath = UserDefaults.standard.string(forKey: "videoPath"), !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: url.path) {
                videoURL = url
            }
        }
        
        guard let finalVideoURL = videoURL else {
            print("No video source found. Hiding wallpaper window overlay.")
            self.orderOut(nil)
            
            cleanUpOldPlayer(currentPlayer, layer: currentPlayerLayer)
            currentPlayer = nil
            currentLooper = nil
            currentPlayerLayer = nil
            return
        }
        
        self.orderFrontRegardless()
        
        let asset = AVURLAsset(url: finalVideoURL)
        let playerItem: AVPlayerItem
        
        // Strip audio tracks completely for seamless, gapless looping
        let composition = AVMutableComposition()
        if let videoTrack = asset.tracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
            playerItem = AVPlayerItem(asset: composition)
        } else {
            playerItem = AVPlayerItem(asset: asset)
        }
        
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        let newLayer = AVPlayerLayer(player: queuePlayer)
        newLayer.frame = NSRect(origin: .zero, size: frame.size)
        newLayer.videoGravity = .resizeAspectFill
        
        if self.contentView == nil {
            let contentView = NSView(frame: frame)
            contentView.wantsLayer = true
            self.contentView = contentView
        }
        
        // If we already have a player playing, perform a cross-fade transition
        let transitionDuration = UserDefaults.standard.double(forKey: "transitionDuration")
        let actualDuration = transitionDuration > 0 ? transitionDuration : 0.5
        
        if let oldLayer = currentPlayerLayer, let oldPlayer = currentPlayer {
            newLayer.opacity = 0.0
            self.contentView?.layer?.addSublayer(newLayer)
            
            let speed = UserDefaults.standard.double(forKey: "playbackSpeed")
            let actualSpeed = speed > 0 ? Float(speed) : 1.0
            
            if !isLowPowerModeActive && !isObscured && !isManualPaused {
                queuePlayer.play()
                queuePlayer.rate = actualSpeed
            }
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(actualDuration)
            CATransaction.setCompletionBlock { [weak self] in
                guard let self = self, !self.isTornDown else { return }
                self.cleanUpOldPlayer(oldPlayer, layer: oldLayer)
            }
            
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0.0
            fadeIn.toValue = 1.0
            fadeIn.duration = actualDuration
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            newLayer.add(fadeIn, forKey: "fadeIn")
            newLayer.opacity = 1.0
            
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1.0
            fadeOut.toValue = 0.0
            fadeOut.duration = actualDuration
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            oldLayer.add(fadeOut, forKey: "fadeOut")
            oldLayer.opacity = 0.0
            
            CATransaction.commit()
        } else {
            self.contentView?.layer?.addSublayer(newLayer)
            let speed = UserDefaults.standard.double(forKey: "playbackSpeed")
            let actualSpeed = speed > 0 ? Float(speed) : 1.0
            
            if !isLowPowerModeActive && !isObscured && !isManualPaused {
                queuePlayer.play()
                queuePlayer.rate = actualSpeed
            }
        }
        
        self.currentPlayer = queuePlayer
        self.currentLooper = looper
        self.currentPlayerLayer = newLayer
        
        if targetScreen == NSScreen.main {
            syncLockScreenWallpaper(videoURL: finalVideoURL)
        }
        
        updatePlaybackState()
    }
    
    private func cleanUpOldPlayer(_ oldPlayer: AVQueuePlayer?, layer: AVPlayerLayer?) {
        oldPlayer?.pause()
        oldPlayer?.cancelPendingPrerolls()
        layer?.player = nil
        oldPlayer?.replaceCurrentItem(with: nil)
        layer?.removeFromSuperlayer()
    }
    
    private func syncLockScreenWallpaper(videoURL: URL) {
        let fileManager = FileManager.default
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        let outputURL = cachesURL.appendingPathComponent("live_wallpaper_fallback.png")
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 60)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
            try pngData.write(to: outputURL)
            print("Successfully extracted first frame to: \(outputURL.path)")
        } catch {
            print("Failed to extract lock screen wallpaper preview: \(error)")
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(workspaceNotificationReceived), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(workspaceNotificationReceived), name: NSWorkspace.didHideApplicationNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(workspaceNotificationReceived), name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(wallpaperVideoChanged), name: .wallpaperVideoChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(manualTogglePlayback), name: Notification.Name("manualTogglePlayback"), object: nil)
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkOcclusion()
        }
    }
    
    @objc private func manualTogglePlayback() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isManualPaused.toggle()
            print("Manual pause toggled: \(self.isManualPaused)")
            self.updatePlaybackState()
        }
    }
    
    @objc private func wallpaperVideoChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupPlayer(frame: self.frame)
        }
    }
    
    @objc private func powerStateChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLowPowerModeActive = ProcessInfo.processInfo.isLowPowerModeEnabled
            print("Low Power Mode changed: \(self.isLowPowerModeActive)")
            self.updatePlaybackState()
        }
    }
    
    @objc private func workspaceNotificationReceived(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.checkOcclusion()
        }
    }
    
    @objc func checkOcclusion() {
        let screenFrame = targetScreen.frame
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        
        var obscuredByWindow = false
        let myPid = ProcessInfo.processInfo.processIdentifier
        
        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            
            if let ownerPid = window[kCGWindowOwnerPID as String] as? Int32, ownerPid == myPid {
                continue
            }
            
            if let ownerName = window[kCGWindowOwnerName as String] as? String, ownerName == "Finder" {
                continue
            }
            
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? CGFloat,
               let y = boundsDict["Y"] as? CGFloat,
               let width = boundsDict["Width"] as? CGFloat,
               let height = boundsDict["Height"] as? CGFloat {
                
                if x <= (screenFrame.minX + 5) && y <= (screenFrame.minY + 5) && 
                   (x + width) >= (screenFrame.maxX - 5) && (y + height) >= (screenFrame.maxY - 5) {
                    obscuredByWindow = true
                    break
                }
            }
        }
        
        if self.isObscured != obscuredByWindow {
            self.isObscured = obscuredByWindow
            print("Occlusion state changed on screen \(targetScreen.localizedName): isObscured = \(self.isObscured)")
            updatePlaybackState()
        }
    }

    private func updatePlaybackState() {
        guard let player = self.currentPlayer else { return }
        
        let speed = UserDefaults.standard.double(forKey: "playbackSpeed")
        let actualSpeed = speed > 0 ? Float(speed) : 1.0
        
        if isLowPowerModeActive || isObscured || isManualPaused {
            if player.rate != 0 {
                print("Pausing video on screen \(targetScreen.localizedName)")
                player.pause()
            }
        } else {
            if player.rate == 0 {
                print("Playing video on screen \(targetScreen.localizedName) at speed \(actualSpeed)")
                player.play()
                player.rate = actualSpeed
            } else if player.rate != actualSpeed {
                player.rate = actualSpeed
            }
        }
        
        NotificationCenter.default.post(name: .wallpaperStatusUpdated, object: nil)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        currentPlayerLayer?.frame = NSRect(origin: .zero, size: frameRect.size)
    }
}
