import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    var wallpaperWindows: [NSScreen: WallpaperWindow] = [:]
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?
    
    private var shuffleTimer: Timer?
    private var isScreenLocked = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Setup initial wallpaper windows for all screens
        updateWallpaperWindows()

        setupStatusItem()
        
        // Auto-open preferences on launch if no wallpaper is set
        let path = UserDefaults.standard.string(forKey: "videoPath") ?? ""
        if path.isEmpty {
            openPreferences()
        }
        
        // Observe screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Observe screen lock / unlock globally
        let distCenter = DistributedNotificationCenter.default
        distCenter.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distCenter.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        
        // Observe system sleep / wake via NSWorkspace
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        
        // Start shuffle timer if enabled
        setupShuffleTimer()
        
        // Observe manual shuffle requests from settings panel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerShuffleNotificationReceived),
            name: .triggerWallpaperShuffle,
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shuffleTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPreferences()
        return true
    }
    
    @objc private func screenLocked() {
        print("AppDelegate: Screen locked. Tearing down all wallpaper windows.")
        isScreenLocked = true
        DispatchQueue.main.async { [weak self] in
            self?.closeWallpaperWindows()
        }
    }
    
    @objc private func screenUnlocked() {
        print("AppDelegate: Screen unlocked.")
        isScreenLocked = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            guard !self.isScreenLocked else { return }
            self.updateWallpaperWindows(animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { [weak self] in
                guard let self = self, !self.isScreenLocked else { return }
                self.restartWallpaperAgent()
            }
        }
    }
    
    @objc private func systemWillSleep(_ notification: Notification) {
        print("AppDelegate: System will sleep. Proactively tearing down wallpaper windows.")
        isScreenLocked = true
        DispatchQueue.main.async { [weak self] in
            self?.closeWallpaperWindows()
        }
    }
    
    @objc private func systemDidWake(_ notification: Notification) {
        print("AppDelegate: System woke from sleep.")
        guard isScreenLocked else { return }
        isScreenLocked = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, !self.isScreenLocked else { return }
            self.updateWallpaperWindows(animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { [weak self] in
                guard let self = self, !self.isScreenLocked else { return }
                self.restartWallpaperAgent()
            }
        }
    }
    
    private func restartWallpaperAgent() {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["WallpaperAgent"]
            try? process.run()
            process.waitUntilExit()
            print("AppDelegate: WallpaperAgent restarted — fresh lock-screen session ready.")
        }
    }
    
    func closeWallpaperWindows() {
        for (_, window) in wallpaperWindows {
            window.tearDown()
            window.close()
        }
        wallpaperWindows.removeAll()
    }
    
    @objc private func screensDidChange(_ notification: Notification) {
        print("Screen configuration changed. Updating wallpaper windows.")
        DispatchQueue.main.async { [weak self] in
            self?.updateWallpaperWindows()
        }
    }
    
    func updateWallpaperWindows(animated: Bool = false) {
        guard !isScreenLocked else {
            print("AppDelegate: Screen is locked. Skipping wallpaper window updates.")
            return
        }
        
        // Clean up windows for screens that are no longer present
        let currentScreens = NSScreen.screens
        for (screen, window) in wallpaperWindows {
            if !currentScreens.contains(screen) {
                window.close()
                wallpaperWindows.removeValue(forKey: screen)
            }
        }
        
        // Create windows for new screens
        for screen in currentScreens {
            if wallpaperWindows[screen] == nil {
                let window = WallpaperWindow(screen: screen, fadeIn: animated)
                wallpaperWindows[screen] = window
            } else {
                wallpaperWindows[screen]?.setFrame(screen.frame, display: true)
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let image: NSImage?
            if let path = Bundle.main.path(forResource: "MenuIcon", ofType: "svg"),
               let img = NSImage(contentsOfFile: path) {
                image = img
            } else if let img = NSImage(named: "MenuIcon") {
                image = img
            } else {
                image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "Live Wallpaper")
            }
            
            if let image = image {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🖼️"
            }
        }
        
        let menu = NSMenu()
        let togglePlayItem = NSMenuItem(title: "Pause", action: #selector(togglePlayback), keyEquivalent: "p")
        menu.addItem(togglePlayItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        menu.delegate = self
    }
    
    @objc private func togglePlayback() {
        NotificationCenter.default.post(name: Notification.Name("manualTogglePlayback"), object: nil)
    }

    @objc private func openPreferences() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Live Wallpaper"
            window.titlebarSeparatorStyle = .automatic
            window.toolbarStyle = .unified
            window.hasShadow = true
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace]
            window.delegate = self
            window.contentMinSize = NSSize(width: 720, height: 480)
            window.setFrameAutosaveName("LiveWallpaperSettingsWindow")
            self.settingsWindow = window
        }
        
        // Transition activation policy to .regular so Stage Manager manages the window
        NSApp.setActivationPolicy(.regular)
        
        // Bring to front
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Shuffle Mode
    
    @objc private func triggerShuffleNotificationReceived() {
        rotateWallpaper()
    }
    
    func setupShuffleTimer() {
        shuffleTimer?.invalidate()
        shuffleTimer = nil
        
        guard UserDefaults.standard.bool(forKey: "shuffleEnabled") else { return }
        
        let interval = UserDefaults.standard.double(forKey: "shuffleInterval")
        let actualInterval = interval > 0 ? interval : 60.0
        
        shuffleTimer = Timer.scheduledTimer(withTimeInterval: actualInterval, repeats: true) { [weak self] _ in
            self?.rotateWallpaper()
        }
    }
    
    private func rotateWallpaper() {
        let fileManager = FileManager.default
        let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                            .appendingPathComponent("com.example.LiveWallpaper")
                                            .appendingPathComponent("Library")
        
        do {
            let files = try fileManager.contentsOfDirectory(at: appSupportLibraryDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let videos = files.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext)
            }
            
            guard videos.count > 1 else { return }
            
            let currentPath = UserDefaults.standard.string(forKey: "videoPath") ?? ""
            let currentURL = URL(fileURLWithPath: currentPath)
            
            let choices = videos.filter { $0.path != currentURL.path }
            if let nextWallpaper = choices.randomElement() {
                print("Shuffle: rotating to next wallpaper: \(nextWallpaper.lastPathComponent)")
                UserDefaults.standard.set(nextWallpaper.path, forKey: "videoPath")
                NotificationCenter.default.post(name: .wallpaperVideoChanged, object: nil)
            }
        } catch {
            print("Shuffle error: \(error)")
        }
    }
}

// Delegate to dynamically update menu items
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let playItem = menu.item(at: 0) {
            let isPaused = wallpaperWindows.values.first?.isManualPaused ?? false
            playItem.title = isPaused ? "Resume" : "Pause"
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
