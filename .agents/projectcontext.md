# Project Context - Native macOS Live Wallpaper Engine

This document provides a comprehensive technical overview of the architecture, file organization, core subsystems, technical resolutions, and development workflows for the Live Wallpaper project.

---

## Project Structure and Architecture

The codebase is organized into a modular Swift architecture (AppKit lifecycle, SwiftUI Liquid Glass UI, AVFoundation playback engine, and background services):

```
live-wallpaper/
├── Sources/
│   ├── App/
│   │   ├── LiveWallpaperApp.swift          # @main entrypoint and AppKit delegate adaptor
│   │   └── AppDelegate.swift               # NSStatusItem menu, sleep/lock observers, shuffle timer, window management
│   ├── Models/
│   │   ├── WallpaperItem.swift             # Wallpaper library model and YouTube metadata
│   │   └── EngineState.swift               # Playback status, power state, and telemetry models
│   ├── Engine/
│   │   └── WallpaperWindow.swift           # Borderless desktop overlay window, AVPlayerLayer, occlusion, crossfade
│   ├── Services/
│   │   ├── WallpaperStoreService.swift     # macOS entries.json dynamic wallpaper store sync and WallpaperAgent control
│   │   ├── VideoTranscodeService.swift     # Hardware-accelerated HEVC transcode and audio stripping
│   │   ├── YouTubeDownloaderService.swift  # Background video downloader engine (yt-dlp integration)
│   │   ├── ThumbnailService.swift          # Asynchronous frame extractor with NSCache memory pooling
│   │   └── FallbackDesktopService.swift    # CoreGraphics dark-mode instructions bitmap generator
│   └── Views/
│       ├── SettingsView.swift              # Main window coordinator and NavigationSplitView sidebar navigation
│       ├── Dashboard/                      # Real-time engine telemetry, hero preview, and monitor layout
│       │   ├── DashboardView.swift
│       │   ├── ActiveWallpaperHeroCard.swift
│       │   ├── MonitorArrangementView.swift
│       │   └── DiagnosticsMetricsGrid.swift
│       ├── Wallpaper/                      # Wallpaper library manager and YouTube downloader interface
│       │   ├── WallpaperSettingsView.swift
│       │   ├── WallpaperLibraryCard.swift
│       │   └── YouTubeDownloaderSection.swift
│       ├── Settings/                       # Native grouped Form for speed sliders, crossfade presets, auto-shuffle
│       │   └── EngineSettingsView.swift
│       ├── About/                          # Versioning, author credits, and information
│       │   └── AboutView.swift
│       └── Components/                     # Notification constants
│           └── NotificationNames.swift
├── Resources/
│   ├── Info.plist                          # Application bundle configuration (LSUIElement = true)
│   ├── entitlements.plist                  # Code signing entitlements
│   ├── AppIcon.icns                        # Multi-resolution macOS icon bundle
│   ├── App Icon.png                        # Master application icon
│   ├── Menu Icon.svg                       # Dynamic vector status menu template icon
│   └── Media.xcassets/                     # Xcode Asset Catalog containing compiled assets
├── scripts/
│   ├── build.sh                            # Recursive build and codesigning script
│   └── make_dmg.sh                         # DMG packaging script
├── build.sh                                # Root convenience wrapper calling scripts/build.sh
├── make_dmg.sh                             # Root convenience wrapper calling scripts/make_dmg.sh
├── .agents/
│   ├── agents.md                           # AI agent guidelines, rules, and technical invariants
│   ├── projectcontext.md                   # Detailed internal engineering architecture notes
│   └── skills/                             # Agent skills and macOS development knowledge modules
│       ├── macos-development/
│       └── macos-golden-gate-design/
└── dmg_maker/                              # Standalone Swift Package for generating installer DMGs
```

### Module Responsibilities

* **LiveWallpaperApp.swift**: SwiftUI `@main` lifecycle entrypoint bridging AppKit execution through `@NSApplicationDelegateAdaptor(AppDelegate.self)`. Declares native `Settings` scene hosting `SettingsView`.
* **AppDelegate.swift**: Coordinates `NSStatusItem` menu, workspace sleep/wake and distributed lock/unlock notification observers, shuffle timer, and multi-monitor `WallpaperWindow` lifecycle.
* **WallpaperWindow.swift**: Borderless `NSWindow` overlay pinned at `CGWindowLevelForKey(.desktopWindow)`. Manages `AVQueuePlayer`, `AVPlayerLooper`, occlusion polling (`kCGWindowListOptionOnScreenOnly`), Low Power Mode detection, and two-phase unlock image-to-video crossfades.
* **WallpaperStoreService.swift**: Manages integration with native macOS `entries.json` dynamic wallpaper store, deterministic static UUID alignment (`LW000000-0000-4000-8000-000000000003`), and `WallpaperAgent` restarts.
* **VideoTranscodeService.swift**: Converts non-compliant video formats to hardware-accelerated HEVC (H.265 `hvc1`) and strips audio streams.
* **YouTubeDownloaderService.swift**: Locates `yt-dlp` in system paths and downloads online videos directly into Application Support storage.
* **ThumbnailService.swift**: Background frame extractor using `AVAssetImageGenerator` and RAM caching with `NSCache<NSURL, NSImage>`.
* **FallbackDesktopService.swift**: Generates a high-resolution dark-mode onboarding image when no wallpaper is selected and applies it via `NSWorkspace.shared.setDesktopImageURL`.
* **SettingsView.swift**: Master navigation coordinator implementing a native macOS 27 `NavigationSplitView` with a full-height sidebar, optional selection bindings, and unified toolbar integration.
* **DashboardView.swift**: Unboxed real-time telemetry dashboard, screen arrangement topology viewer, and native toolbar quick controls (Pause/Resume, Shuffle, Restart).
* **WallpaperSettingsView.swift**: Native desktop wallpaper gallery supporting `.searchable` filename search, drag-and-drop video imports, contextual menus, and YouTube downloader sheet/popover.
* **EngineSettingsView.swift**: Native grouped `Form` (`.formStyle(.grouped)`) for playback speed multipliers (0.5x to 2.0x), crossfade presets (0.1s to 2.0s), auto-shuffle intervals (1m to 1h), and launch-at-login settings.

---

## Key Technical Understandings and Resolutions

### 1. Native macOS Wallpaper Store Integration (Sonoma, Sequoia, Tahoe, Golden Gate)
* **System Location**: macOS Sonoma, Sequoia, Tahoe, and Golden Gate (macOS 27) handle dynamic desktop and lock screen wallpapers through `~/Library/Application Support/com.apple.wallpaper/aerials/`.
* **Database Manifest**: The database managing wallpaper options is located at `manifest/entries.json`.
* **Registration Strategy**: Programmatically registers a custom category (`"Custom Live Wallpaper"`) and subcategory, alongside a dynamic asset (`"Active Wallpaper Feed"`).
* **Static Asset ID Alignment**: To prevent macOS from losing selection and resetting to system defaults on every video update, the app registers a static, constant ID (`"LW000000-0000-4000-8000-000000000003"`). Once the user selects this card in System Settings, it remains mapped. Changing the video simply replaces the video file on disk and restarts the WallpaperAgent, keeping the user selection active.
* **Wallpaper Agent Sync**: Runs `killall WallpaperAgent` to force System Settings to reload modified database entries immediately.

> [!CRITICAL]
> Do NOT call `NSWorkspace.shared.setDesktopImageURL` at any point during the lock/unlock cycle. This permanently overwrites WallpaperAgent's HEVC video selection in the macOS preferences database, causing the lock screen to display a static image on subsequent locks. Only call `setDesktopImageURL` when the library is intentionally cleared.

### 2. Startup Persistence vs. Cache Resets
* **The Issue**: Registering a new UUID database entry on every application launch caused macOS System Settings to lose track of the previously selected wallpaper (resetting to macOS default).
* **The Resolution**: Database registration was removed from the startup cycle (`onAppear`). Database writes only occur when a user explicitly changes, imports, or clicks "Apply" on a wallpaper, preserving the active selection across reboots.

### 3. Native Lock Screen Decoders and WallpaperAgent (macOS 26 Tahoe / macOS 27 Golden Gate)
* **Codec Strictness**: The macOS secure lock screen player uses low-level hardware decoding. Standard H.264 video tracks fail (showing a black screen) on subsequent lock screen events. Background transcoding forces native H.265 (HEVC) using the `AVAssetExportPresetHEVCDeliverable` preset, ensuring compatibility with secure OS decoders.
* **GPU Thread Contention (Global Lifecycle Teardown)**: Playing overlay videos on the desktop while the Lock Screen is active causes VideoToolbox contention. The `AppDelegate` listens for events globally and uses a three-pronged strategy:
  * **`NSWorkspace.willSleepNotification` (BEFORE lock)**: Fires before the display sleeps, proactively invoking `tearDown()` and `close()` on desktop overlays before WallpaperAgent renders the lock screen.
  * **`com.apple.screenIsLocked` (AFTER lock)**: Fallback for keyboard-shortcut locks (Cmd+Ctrl+Q) where `willSleepNotification` is not dispatched.
  * **On Unlock (`com.apple.screenIsUnlocked` / `NSWorkspace.didWakeNotification`)**: After a `0.1s` safety margin, `AppDelegate` recreates desktop overlay windows using `updateWallpaperWindows(animated: true)`. At `~2.0s` from unlock it then calls `restartWallpaperAgent()`.
* **`restartWallpaperAgent()`**: WallpaperAgent's internal lock-screen video session becomes stale after the first lock/unlock cycle. Killing and restarting it forces a complete re-read of `entries.json` and a fresh video session initialization. Timing: `0.1s start + 0.6s thumbnail + 0.7s fade + 0.5s buffer = ~1.9s from unlock`.
* **`tearDown()` Explicit Hardware Decoder Release**: `isReleasedWhenClosed = false` means `close()` only hides the window without triggering `deinit`, leaving VideoToolbox decoders allocated. `tearDown()` performs the complete release sequence: `cancelPendingPrerolls()` -> `layer.player = nil` -> `replaceCurrentItem(nil)` -> `removeFromSuperlayer()` -> nil strong references. Always called before `close()`.
* **Cross-Fade Guard (`isTornDown`)**: Guards `CATransaction` completion blocks with `isTornDown` to prevent old player callbacks from accessing already-released state mid-lock.

### 4. Seamless Unlock Transition - Image to Video Crossfade
* **The Problem**: On unlock, a blank/black period occurred before the video overlay reappeared due to window creation latency.
* **The Solution**: When recreating windows after unlock (`fadeIn: true`), `WallpaperWindow` uses a two-phase reveal:
  1. **Window starts invisible** (`alphaValue = 0`).
  2. **Thumbnail overlay mounted while invisible**: Loads cached first-frame PNG (`~/Library/Caches/live_wallpaper_fallback.png`) as a `CALayer` on top of the player layer while `alphaValue = 0`.
  3. **Instant reveal**: `alphaValue` snaps to `1.0` once the thumbnail layer is confirmed in place.
  4. **Thumbnail fades out to video**: After `0.6s`, `fadeThumbnailOut(duration: 0.7)` uses a `CABasicAnimation` on opacity, dissolving the still image while live video plays beneath.
  5. **Removal**: Once animation completes, thumbnail layer is detached from hierarchy.

### 5. Sandbox Permissions on Startup (TCC)
* When a video is selected or dropped, the app copies the file into its own Application Support directory (`com.example.LiveWallpaper/Library/`). It plays and registers the copied path directly, ensuring it remains fully readable at startup without security permission loss.

### 6. Gapless Video Looping & Modern AVFoundation Concurrency
* `AVPlayerLooper` is initialized with an empty `AVQueuePlayer()`.
* Audio tracks are stripped completely via `AVMutableComposition` and `ffmpeg -an`, avoiding audio hardware clock sync delays and ensuring seamless loop transitions.
* **Modern Async Property Loading**: Replaced deprecated synchronous AVAsset accessors with async methods (`loadTracks(withMediaType:)`, `load(.duration)`, and `load(.preferredTransform)`).
* **Task Cancellation Management**: `setupPlayer` runs inside a managed `Task { @MainActor in ... }` stored in `setupPlayerTask`. Any subsequent call to `setupPlayer()` or `tearDown()` immediately cancels any inflight task to avoid decoder race conditions.

### 7. Asynchronous UI and RAM Caching
* Grid thumbnails load concurrently on `DispatchQueue.global(qos: .userInitiated)`.
* In-memory cache uses `NSCache<NSURL, NSImage>` with automatic system memory pressure eviction.
* Layout height placeholders prevent grid jumping while metadata resolves.

### 8. Stage Manager and macOS 27 Window Architecture
* When Settings is opened, application activation policy switches to `.regular` to participate in Dock and Stage Manager spaces. When closed, it reverts to `.accessory`.
* **Safe Area Insets**: Removing `safeAreaRegions = []` from `NSHostingController` ensures `NavigationSplitView` properly respects window titlebar safe area insets. The sidebar material naturally reaches the top window edge while detail views stay properly aligned below the toolbar.
* **Scroll-Edge Material Diffusion**: Setting `window.titlebarSeparatorStyle = .automatic` and applying `.toolbarBackground(.visible, for: .windowToolbar)` ensures that when detail content (such as Preferences `Form` or Library grid) scrolls up, it diffuses cleanly behind the Liquid Glass toolbar with a subtle separator line, preventing text collisions with the window title.
* **NavigationSplitView Optional Selection**: Declaring `@State private var selectedItem: SettingsNavigationItem?` ensures `List(selection:)` handles macOS sidebar selection changes reliably.

### 9. SwiftUI Modernization for macOS 27
* All `.onChange` calls migrated to modern zero-argument or two-argument `(oldValue, newValue)` forms, resolving deprecation warnings under macOS 27 and Swift 6.4.

### 10. macOS 27 Golden Gate UI Overhaul
* Implemented according to the `macos-golden-gate-design` skill guidelines:
  * **Zero Card Budget**: Replaced nested `.ultraThinMaterial` and `.thinMaterial` rounded cards with flat, scannable detail planes.
  * **Native Grouped Form**: Migrated Preferences from custom `VStack` card sections to a standard `Form` with `.formStyle(.grouped)`.
  * **Unified Toolbar Placement**: Migrated action buttons (Play/Pause, Shuffle, Restart WallpaperAgent, Add Wallpaper) to native macOS `.toolbar` items with keyboard shortcuts (`Space`, `Cmd+R`, `Cmd+O`).
  * **Native Desktop Gallery**: Wallpaper gallery uses adaptive grids, double-click to apply, `.searchable` filtering, and macOS `.contextMenu` actions.

---

## Build and Packaging Runbook

### Prerequisites
* macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), macOS 26.0 (Tahoe), or macOS 27.0 (Golden Gate)
* Xcode Command Line Tools or Xcode 27+ (`swiftc` 6.0+)
* Optional: `yt-dlp` and `ffmpeg` for YouTube video downloading

### Compilation
Run from project root:
```bash
./build.sh
```
This executes `scripts/build.sh`, resolves the matching SDK dynamically (Xcode 27 SDK on macOS 27), compiles all Swift sources recursively, copies bundle resources and SVG templates, compiles the asset catalog, and ad-hoc signs the application.

### DMG Generation
Run from project root:
```bash
./make_dmg.sh
```
This builds and executes the standalone `dmg_maker` tool to produce `Live Wallpaper.dmg`. Whenever changes are made to application code or resources, always run `./make_dmg.sh` after `./build.sh` so the packaged disk image reflects the latest build.

---

## Gatekeeper Handling

For ad-hoc builds run outside the Mac App Store:
1. Open System Settings -> Privacy & Security -> Security.
2. Under "LiveWallpaper was blocked from use", click "Open Anyway".
3. Or clear quarantine attributes via terminal:
```bash
xattr -cr /path/to/LiveWallpaper.app
```

