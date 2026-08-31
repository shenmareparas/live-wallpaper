# Project Documentation - Native macOS Live Wallpaper Engine

This document outlines the architecture, file structure, key technical solutions, and developer understandings for the Live Wallpaper project. It serves as a comprehensive developer reference.

---

## 📂 Project Structure & Architecture

The codebase is organized into a modular Swift architecture (AppKit lifecycle + SwiftUI liquid glass UI + AVFoundation engine + Services):

```
live-wallpaper/
├── Sources/
│   ├── App/
│   │   ├── LiveWallpaperApp.swift          # @main entrypoint & AppKit delegate adaptor
│   │   └── AppDelegate.swift               # NSStatusItem menu, sleep/lock observers, shuffle timer, window management
│   ├── Models/
│   │   ├── WallpaperItem.swift             # Wallpaper library model & YouTube metadata
│   │   └── EngineState.swift               # Playback status, power state, and telemetry models
│   ├── Engine/
│   │   └── WallpaperWindow.swift           # Borderless desktop overlay window, AVPlayerLayer, occlusion & crossfade
│   ├── Services/
│   │   ├── WallpaperStoreService.swift     # macOS entries.json dynamic wallpaper store sync & WallpaperAgent control
│   │   ├── VideoTranscodeService.swift     # Hardware-accelerated HEVC transcode & audio stripping
│   │   ├── YouTubeDownloaderService.swift  # Background video downloader engine (yt-dlp integration)
│   │   ├── ThumbnailService.swift          # Asynchronous frame extractor with NSCache memory pooling
│   │   └── FallbackDesktopService.swift    # CoreGraphics dark-mode instructions bitmap generator
│   └── Views/
│       ├── SettingsView.swift              # Main window coordinator & liquid glass sidebar navigation
│       ├── Dashboard/                      # Real-time engine telemetry, hero preview, and monitor layout
│       │   ├── DashboardView.swift
│       │   ├── ActiveWallpaperHeroCard.swift
│       │   ├── MonitorArrangementView.swift
│       │   ├── WaveformPulseView.swift
│       │   └── DiagnosticsMetricsGrid.swift
│       ├── Wallpaper/                      # Wallpaper library manager & YouTube downloader interface
│       │   ├── WallpaperSettingsView.swift
│       │   ├── WallpaperLibraryCard.swift
│       │   └── YouTubeDownloaderSection.swift
│       ├── Settings/                       # Speed sliders, crossfade presets & auto-shuffle timers
│       │   └── EngineSettingsView.swift
│       ├── About/                          # Versioning, author credits & GitHub links
│       │   └── AboutView.swift
│       └── Components/                     # Reusable glassmorphic UI primitives & notifications
│           ├── VisualEffectView.swift
│           ├── TabButton.swift
│           ├── CustomCorners.swift
│           └── NotificationNames.swift
├── Resources/
│   ├── Info.plist                          # Application bundle configuration (LSUIElement = true)
│   ├── entitlements.plist                  # Code signing entitlements
│   ├── AppIcon.icns                        # Multi-resolution macOS icon bundle
│   ├── App Icon.png                        # Master application icon
│   ├── Menu Icon.svg                       # Dynamic vector status menu template icon
│   └── Media.xcassets/                     # Xcode Asset Catalog containing compiled assets
├── scripts/
│   ├── build.sh                            # Main recursive build and signing script
│   └── make_dmg.sh                         # DMG packaging script
├── build.sh                                # Root convenience wrapper calling scripts/build.sh
├── make_dmg.sh                             # Root convenience wrapper calling scripts/make_dmg.sh
└── dmg_maker/                              # Standalone Swift Package for generating installer DMGs
```

### Module Responsibilities:

*   **[LiveWallpaperApp.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/App/LiveWallpaperApp.swift)**: SwiftUI `@main` lifecycle entrypoint bridging AppKit execution through `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
*   **[AppDelegate.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/App/AppDelegate.swift)**: Coordinates `NSStatusItem` menu, global workspace sleep/wake and distributed lock/unlock notification observers, shuffle timer, and multi-monitor `WallpaperWindow` lifecycle.
*   **[WallpaperWindow.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Engine/WallpaperWindow.swift)**: Borderless `NSWindow` overlay pinned at `CGWindowLevelForKey(.desktopWindow)`. Manages `AVQueuePlayer`, `AVPlayerLooper`, occlusion polling (`kCGWindowListOptionOnScreenOnly`), Low Power Mode detection, and two-phase unlock image-to-video crossfades.
*   **[WallpaperStoreService.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Services/WallpaperStoreService.swift)**: Manages integration with native macOS `entries.json` dynamic wallpaper store, deterministic static UUID alignment (`LW000000-0000-4000-8000-000000000003`), and `WallpaperAgent` restarts.
*   **[VideoTranscodeService.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Services/VideoTranscodeService.swift)**: Converts non-compliant video formats to hardware-accelerated HEVC (H.265 `hvc1`) and strips audio streams.
*   **[YouTubeDownloaderService.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Services/YouTubeDownloaderService.swift)**: Locates `yt-dlp` in system paths and downloads online videos directly into Application Support storage.
*   **[ThumbnailService.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Services/ThumbnailService.swift)**: Background frame extractor using `AVAssetImageGenerator` and RAM caching with `NSCache<NSURL, NSImage>`.
*   **[FallbackDesktopService.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Services/FallbackDesktopService.swift)**: Generates a high-resolution dark-mode onboarding image when no wallpaper is selected and applies it via `NSWorkspace.shared.setDesktopImageURL`.
*   **[SettingsView.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Views/SettingsView.swift)**: Master navigation coordinator implementing Liquid Glass sidebar aesthetics, Stage Manager activation policy switching (`.regular` $\leftrightarrow$ `.accessory`), and tab switching.
*   **[EngineSettingsView.swift](file:///Users/parasshenmare/Developer/other_projects/live-wallpaper/Sources/Views/Settings/EngineSettingsView.swift)**: Playback speed multipliers (0.5x–2.0x), crossfade presets (0.1s–2.0s), auto-shuffle intervals (1m–1h), and launch-at-login settings.

---

## 🛠️ Key Technical Understandings & Resolutions

### 1. Native macOS Wallpaper Store Integration (Sonoma, Sequoia, Tahoe)
*   **System Location**: macOS Sonoma, Sequoia, and Tahoe handle dynamic desktop and lock screen wallpapers through `~/Library/Application Support/com.apple.wallpaper/aerials/`.
*   **Database Manifest**: The database managing wallpaper options is located at `manifest/entries.json`.
*   **Registration Strategy**: We programmatically register a custom category (`"Custom Live Wallpaper"`) and subcategory, alongside a dynamic asset (`"Active Wallpaper Feed"`).
*   **Static Asset ID Alignment**: To prevent macOS from losing selection and resetting to system defaults on every video update, the app registers a **static, constant ID** (`"LW000000-0000-4000-8000-000000000003"`). Once the user selects this card in System Settings, it remains mapped. Changing the video simply replaces the video file on disk and restarts the WallpaperAgent, keeping the user selection active.
*   **Wallpaper Agent Sync**: We run `killall WallpaperAgent` to force System Settings to reload the modified database entries immediately.

> **⚠️ Critical**: Do NOT call `NSWorkspace.shared.setDesktopImageURL` at any point during the lock/unlock cycle. This permanently overwrites WallpaperAgent's HEVC video selection in the macOS preferences database, causing the lock screen to display a static image on subsequent locks. Only call `setDesktopImageURL` when the library is intentionally cleared (setup guide fallback).

### 2. Startup Persistence vs. Cache-Resets
*   **The Issue**: Registering a new UUID database entry every time the app launches caused macOS System Settings to lose track of the previously selected wallpaper (resetting it to macOS default).
*   **The Resolution**: We removed database registration from the startup cycle (`onAppear`). Database writes only occur when a user **explicitly** changes, imports, or clicks "Apply" on a wallpaper, preserving the active selection across reboots.

### 3. Native Lock Screen Black Screen Glitches & Decoders (macOS 26 / Tahoe specific)
*   **Codec Strictness**: The macOS secure lock screen player uses low-level hardware decoding. Standard H.264 video tracks fail (showing a black screen) on subsequent lock screen events. We bypass the passthrough preset and force a background transcode to native **H.265 (HEVC)** using the `AVAssetExportPresetHEVCDeliverable` preset, ensuring compatibility with secure OS decoders.
*   **GPU Thread Contention (Global Lifecycle Teardown)**: Playing overlay videos on the desktop while the Lock Screen is active causes VideoToolbox contention. The `AppDelegate` listens for events globally and uses a three-pronged strategy:
    *   **`NSWorkspace.willSleepNotification` (BEFORE lock)**: Fires *before* the display sleeps, giving us a proactive chance to call `tearDown()` + `close()` on desktop overlays before WallpaperAgent renders the lock screen. Unlike `com.apple.screenIsLocked` which fires *after* the lock screen has already rendered, this is the earliest safe teardown point for sleep-triggered locks.
    *   **`com.apple.screenIsLocked` (AFTER lock)**: Used as a fallback for keyboard-shortcut locks (Cmd+Ctrl+Q) where `willSleepNotification` is not dispatched.
    *   **On Unlock (`com.apple.screenIsUnlocked` / `NSWorkspace.didWakeNotification`)**: After a `0.1s` safety margin, `AppDelegate` recreates desktop overlay windows using `updateWallpaperWindows(animated: true)`. At `~2.0s` from unlock it then calls `restartWallpaperAgent()`.
*   **`restartWallpaperAgent()` — Key Fix for macOS 26**: WallpaperAgent's internal lock-screen video session becomes **stale** after the first lock/unlock cycle. Killing and restarting it forces a complete re-read of `entries.json` and a fresh video session initialisation, so the next lock always shows the video. This must be called **after** our desktop overlay is fully opaque, so the brief WallpaperAgent static-wallpaper flash during restart is hidden behind our window. Timing: `0.1s start + 0.6s thumbnail + 0.7s fade + 0.5s buffer = ~1.9s from unlock`.
*   **`tearDown()` — Explicit Hardware Decoder Release**: `isReleasedWhenClosed = false` means `close()` only hides the window without triggering `deinit`, leaving VideoToolbox decoders allocated. `tearDown()` performs the full release sequence: `cancelPendingPrerolls()` → `layer.player = nil` → `replaceCurrentItem(nil)` → `removeFromSuperlayer()` → nil all strong references. Always called before `close()`.
*   **Cross-Fade Guard (`isTornDown`)**: If a cross-fade animation is in-flight when the screen locks, the `CATransaction` completion block is guarded by the `isTornDown` flag. This prevents the old player/layer callback from accessing already-released state mid-lock.
*   **Full Decoder Release in `cleanUpOldPlayer`**: During cross-fades, the helper calls `cancelPendingPrerolls()`, `layer.player = nil`, and `replaceCurrentItem(nil)` before removing the layer — not just `pause()` — to prevent zombie decoders accumulating across video transitions.

### 4. Seamless Unlock Transition — Image → Video Crossfade
*   **The Problem**: On unlock, there was a visible blank/black period before the video overlay reappeared, caused by the 0.3–1.0s startup delay before `WallpaperWindow` was created.
*   **The Solution — Thumbnail Overlay Pattern**: When recreating windows after unlock (`fadeIn: true`), `WallpaperWindow` uses a two-phase reveal:
    1. **Window starts invisible** (`alphaValue = 0`): Setup runs without any visible flash. `orderFrontRegardless()` fires inside `setupPlayer` while the window is transparent.
    2. **Thumbnail overlay added while invisible**: `addThumbnailOverlay()` loads the cached first-frame PNG (`~/Library/Caches/live_wallpaper_fallback.png`) as a `CALayer` on top of the player layer — while the window is still at `alphaValue = 0`. No blank frame is possible.
    3. **Instant reveal**: `alphaValue` is snapped to `1.0` only once the thumbnail layer is confirmed in place. The user's first visible pixel from this window is the still image — never black.
    4. **Thumbnail fades out to video**: After `0.6s`, `fadeThumbnailOut(duration: 0.7)` uses a `CABasicAnimation` on the thumbnail layer's `opacity` (independent of any `NSAnimationContext`), dissolving it while the live video plays underneath. Once the animation completes, the layer is removed from the hierarchy.
    5. **Fallback**: If no cached thumbnail exists (first launch / cleared library), the window fades in gently via `NSAnimationContext` over `0.55s`.
*   **Thumbnail source**: `live_wallpaper_fallback.png` is extracted by `syncLockScreenWallpaper` using `AVAssetImageGenerator.copyCGImage` from the first frame of the active video whenever `setupPlayer` runs on the main screen.
*   **`isTornDown` guard in `fadeThumbnailOut`**: The `CATransaction` completion block checks `isTornDown` before removing the thumbnail layer, preventing access to deallocated state if the screen re-locks during the fade.
*   **Complete unlock timeline**:

    | Time after unlock | Event |
    |---|---|
    | `t = 0` | `screenUnlocked` fires, `isScreenLocked = false` |
    | `t = 0.1s` | `WallpaperWindow` created (`alphaValue=0`), player setup, thumbnail overlay placed |
    | `t = 0.1s` | `alphaValue` snapped to `1.0` — user sees first-frame image |
    | `t = 0.7s` | `fadeThumbnailOut(0.7s)` begins — image fades to live video |
    | `t = 1.4s` | Thumbnail layer removed, video playing at full opacity |
    | `t = 2.0s` | `restartWallpaperAgent()` runs — fresh lock-screen session ready for next lock |

### 5. Sandbox Permissions on Startup (TCC)
*   **The Issue**: macOS security protocols block unsigned or local apps from reading files outside their container (e.g., `~/Downloads` or `~/Desktop`) on subsequent launches, causing silent startup failures.
*   **The Resolution**: When a video is selected or dropped, the app copies the file into its own secure Application Support directory (`com.example.LiveWallpaper/Library/`). It then plays and registers the copied path directly, ensuring it remains fully readable at startup.

### 6. Custom Setup Guide Image Fallback
*   **The Issue**: If no video is selected, displaying a black cover hides instructions on how to use the app.
*   **The Resolution**: When the library is cleared, the app uses core drawing APIs to generate a dark-mode instructions image explaining how to enable the wallpaper in System Settings. It then programmatically sets this generated image as the desktop background across all screens using `NSWorkspace.shared.setDesktopImageURL`.

### 7. Gapless Video Looping (AVPlayerLooper & Audio Stripping)
*   **The Issue**: The video paused or glitched briefly at the end of each play cycle before restarting. Additionally, audio playback synchronization in AVFoundation added decode delays.
*   **The Resolution**: 
    *   `AVPlayerLooper` expects the `AVQueuePlayer` to be completely empty upon creation. We initialize the queue player empty (`AVQueuePlayer()`), allowing `AVPlayerLooper` to manage all queue treadmill operations seamlessly from the start.
    *   **Audio Removal**: To prevent AVFoundation from allocating audio decoders and synchronizing the audio hardware clock at loop boundaries, we completely strip all audio tracks. During import, the HEVC transcoder uses `AVMutableComposition` to export only the video track, and the fallback converter uses `ffmpeg -an`. Furthermore, `WallpaperWindow` uses `AVMutableComposition` to load a video-only asset. This removes the audio pipeline entirely, guaranteeing frame-perfect, continuous loop playback.

### 8. YouTube URL Preservation & Storage
*   **The Issue**: Wallpapers downloaded from YouTube did not retain their source links, making it difficult for the user to find the original web video.
*   **The Resolution**: When downloading a video via the YouTube downloader engine, we extract the source URL and map it to the saved local filename. This mapping is persisted in a `"youtubeURLs"` dictionary inside `UserDefaults`. When a wallpaper is deleted, its entry is automatically cleaned up from `UserDefaults`. A button in the `WallpaperLibraryCard` hover overlay opens this link back in the web browser.

### 9. High-Performance Asynchronous UI & RAM Caching
*   **The Issue**: Switching to the Wallpaper tab caused severe UI stutter/freezes as multiple video thumbnails were synchronously decoded, written to disk, and measured on the Main (UI) thread. Furthermore, cards shifted size dynamically as metadata loaded, causing layout grid popping.
*   **The Resolution**:
    *   **Asynchronous Loading**: Grid cards are rendered instantly with a visual placeholder. Thumbnails and file sizes are loaded on a concurrent background queue (`DispatchQueue.global(qos: .userInitiated)`) off the main thread.
    *   **RAM Cache (`NSCache`)**: Loaded images are cached in a static `ThumbnailCache` (`NSCache<NSURL, NSImage>`). On subsequent tab switches, they are read instantly from RAM (taking microseconds) rather than disk. Since it uses `NSCache`, macOS automatically evicts cache items on memory pressure to protect system resource limits.
    *   **Layout Lock**: To prevent shifting boxes, cards reserve layout height placeholders: `Text(fileSizeString.isEmpty ? " " : fileSizeString)`. Rendering a single blank space reserves layout dimensions, keeping the grid perfectly static when file sizes pop in.

### 10. Stage Manager & Unified Window Coordinates
*   **The Issue**: Settings panels running as `.accessory` apps (no Dock icon) are ignored by macOS Stage Manager and don't follow user stages. Also, transparent title bars created transparent safe-area bands at the top and bottom of the settings sidebar.
*   **The Resolution**:
    *   **Dynamic Activation Policy**: When the Settings window is loaded, we promote the app's policy to `.regular` (enabling it to show in the Dock and participate in Stage Manager stages). When closed, the policy reverts to `.accessory` to hide the Dock icon.
    *   **Safe Area Override**: We apply `.ignoresSafeArea()` on the SwiftUI root view and set `hostingController.safeAreaRegions = []` on the AppKit hosting controller. This overrides safe-area offsets, allowing the sidebar material to anchor cleanly from the absolute top to the absolute bottom of the window frame, following the window's native rounded corners.

---

## 🎨 Premium Features Added

*   **Seamless Unlock Transition**: Image-to-video crossfade on every unlock. The cached first-frame PNG shows instantly on unlock, then the live video fades in over ~0.7s — eliminating all blank flashes.
*   **In-App Setup Guide**: Displays step-by-step setup cards natively in the SwiftUI Wallpaper tab when no active wallpaper is set, matching the user instructions generated on the fallback desktop.
*   **Wallpaper Storage Library**: Keeps track of all imported video wallpapers in an internal library folder.
*   **Dynamic Video Thumbnails**: Uses `AVAssetImageGenerator` to extract the first frame of every imported video in the library and displays it as a thumbnail.
*   **Source Web Links**: Integrates a quick-visit browser link button (`play.rectangle.fill`) in the wallpaper library overlay for all YouTube-imported assets.
*   **Premium YouTube Downloader**: An enhanced download panel overlay displaying an exact linear progress bar (`ProgressView(value:total:)`), helper descriptions, and error states with warning icons.
*   **Robust Access**: Implementing `applicationShouldHandleReopen` ensures that double-clicking the app in the Applications folder opens the Preferences screen, even if the menu bar icon is hidden.
*   **Resolution-Independent Dynamic Status Menu Icon**: Custom vector status menu icon processed using a compiled Xcode Asset Catalog (`Assets.car`). Uses the vector SVG with a `template` rendering configuration, permitting macOS to automatically and dynamically tint the status bar icon matching the user's desktop background and light/dark appearance perfectly.
*   **One-Click Professional Installer Builder**: Custom DMG builder integrating the local `DMGMaker` suite. Renders a modern glassmorphic window layout using SwiftUI mesh gradients and custom icon placement.
*   **Overhauled Status Dashboard**: Includes a glowing, color-coded active/suspended status banner alongside a live audio-style video rendering waveform.
*   **Multi-Monitor Arrangement Preview**: Dynamically maps physical screen frame positions and arrangements using `NSScreen.screens` to render an interactive monitor display layout inside the dashboard.
*   **Active Wallpaper Hero Card**: Displays active thumbnail, format info, and file size with direct actions to **Reveal in Finder** and **Visit Source** (for YouTube downloads).
*   **Quick Engine Control Panel**: Quick actions to Pause/Resume, Shuffle (manual rotate), and Restart WallpaperAgent (Tahoe troubleshoot).
*   **Diagnostics Metrics Grid**: Provides real-time rendering statistics, Eco/Normal power modes, obscuration status, and decoder engine type.
*   **Performance Presets**: Quick speed pills (0.5x, 1.0x, 1.5x, 2.0x) and transition style presets (Instant, Balanced, Gradual) for rapid configuration.
*   **Proportional App Sizing**: Settings window resized to 760x540 with max-width boundaries on preferences to comply with HIG sidebar layouts.

---

## 🛡️ First-Time Launch & macOS Gatekeeper Handling

When launching ad-hoc built or downloaded builds outside the Mac App Store, macOS Gatekeeper security policies may trigger a warning modal on first execution:

> *"Live Wallpaper cannot be opened because Apple cannot check it for malicious software"* or *"unidentified developer"*.

### Resolution Workflow for End Users & Testers:
1. Click **Done** / **OK** / **Cancel** to dismiss the initial system dialog.
2. Open **System Settings** $\rightarrow$ navigate to **Privacy & Security**.
3. Scroll down to the **Security** subsection.
4. Locate the message: *"LiveWallpaper was blocked from use because it is not from an identified developer"*.
5. Click **Open Anyway**, authenticate via Touch ID or administrator password, and confirm **Open**.

### Developer Bypass (Quarantine Attribute Removal):
If distributing the `.app` directly or installing locally from a build artifact, remove the `com.apple.quarantine` extended attribute via Terminal:
```bash
xattr -cr /path/to/LiveWallpaper.app
```

