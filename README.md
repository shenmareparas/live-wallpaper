<a href='https://github.com/shenmareparas/live-wallpaper'><img alt='Live Wallpaper App Icon' src="https://raw.githubusercontent.com/shenmareparas/live-wallpaper/master/App%20Icon.png" width="220"/></a>

# 🎬 Live Wallpaper for macOS: Dynamic Desktop & Lock Screen Engine

A lightweight, ultra-optimized native macOS menu bar application built in pure **Swift**, **AppKit**, and **SwiftUI**. Live Wallpaper transforms your Mac desktop and lock screen into a fluid, animated cinematic canvas with hardware-accelerated HEVC playback, gapless video looping, multi-monitor geometry tracking, intelligent power-saving occlusion guards, an integrated YouTube video downloader, and seamless image-to-video unlock crossfading.

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%7C%20Sequoia%20%7C%20Tahoe)-000000?logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-FA7343?logo=swift&logoColor=white)](https://swift.org)
[![AppKit](https://img.shields.io/badge/AppKit-Native-blue.svg)](https://developer.apple.com/documentation/appkit)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-orange.svg)](https://developer.apple.com/xcode/swiftui/)
[![AVFoundation](https://img.shields.io/badge/AVFoundation-Hardware%20HEVC-8E44AD.svg)](https://developer.apple.com/av-foundation/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<a href='https://github.com/shenmareparas/live-wallpaper/raw/master/Live%20Wallpaper.dmg'><img alt='Download DMG for macOS' src='https://img.shields.io/badge/Download-Live_Wallpaper.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white' height='45px'/></a>

---

## ✨ Features

### 🖥️ Native Desktop & Lock Screen Engine

-   **Deep macOS Wallpaper Store Integration**: Seamlessly hooks into the native macOS dynamic wallpaper database (`~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`), ensuring your custom video wallpapers appear in System Settings and persist across OS reboots.
-   **Dual-Layer Desktop & Lock Screen Sync**: Synchronizes animated wallpaper playback between active desktop spaces and the macOS secure lock screen.
-   **Static Manifest ID Alignment**: Employs a deterministic static asset UUID (`LW000000-0000-4000-8000-000000000003`) so System Settings never loses your wallpaper selection or resets to macOS defaults when changing videos.
-   **Multi-Monitor Geometry Mapping**: Automatically detects display arrangements (`NSScreen.screens`), handles hot-plugging, resolution changes, and renders synchronized wallpaper windows for every connected display.
-   **Interactive Monitor Preview**: Live visualizer inside the Dashboard displaying connected monitor orientations, aspect ratios, and active display bounds.

### 🎨 UI & Liquid Glass Design

-   **Modern Liquid Glass Interface**: Translucent vibrancy sidebars, frosted glass panels (`NSVisualEffectView` backing materials), and unified typography with macOS Human Interface Guidelines.
-   **Real-time Status Dashboard**: Glowing, color-coded engine state badge (Active, Suspended, Paused, Eco Mode) paired with an audio-style video rendering pulse waveform.
-   **Active Wallpaper Hero Card**: Displays high-resolution thumbnail previews, video format info, file size, direct **Reveal in Finder** action, and source website links.
-   **Resolution-Independent Menu Bar Icon**: Vector SVG menu bar icon compiled directly into an Xcode Asset Catalog (`Assets.car`) with template rendering for automatic light/dark tinting.
-   **Stage Manager & Dock Policy Switching**: Dynamically promotes activation policy from `.accessory` (stealth menu bar agent) to `.regular` when the Settings panel is opened, allowing it to participate in Stage Manager stages and Cmd+Tab switching.

### 📥 YouTube & Online Video Downloader

-   **Integrated Downloader Engine**: Paste any YouTube video URL to automatically extract, download, transcode, and import it into your wallpaper library.
-   **Linear Progress & Status Feedback**: Real-time download progress bar (`ProgressView(value:total:)`), animated spin indicators, speed metrics, and inline error diagnosis.
-   **Source URL Preservation**: Automatically saves source YouTube URLs to `UserDefaults` and provides a one-click browser launcher on wallpaper cards.
-   **Automatic Audio Stripping**: Strips audio streams during download to guarantee zero audio buffer contention and minimize file footprint.

### 🎛️ Engine Customization & Playback Controls

-   **Playback Speed Multipliers**: Adjustable video playback speed from `0.5x` to `2.0x` with instant-access quick pills (`0.5x`, `1.0x`, `1.5x`, `2.0x`).
-   **Configurable Crossfade Transitions**: Custom transition timing between video changes, ranging from Instant (`0.1s`), Balanced (`0.5s`), to Gradual (`1.2s`).
-   **Automatic Wallpaper Shuffle**: Scheduled wallpaper rotation with customizable timer intervals (1 min, 5 min, 15 min, 30 min, 1 hr, 6 hr, 24 hr).
-   **Drag-and-Drop Library Import**: Drag video files directly onto the app window to automatically transcode and register them. Supports `.mp4`, `.mov`, `.m4v`, `.webm`, `.avi`, `.mkv`.
-   **Setup Guide Fallback Card**: Step-by-step visual onboarding guide automatically presented when no wallpaper is selected.

### ⚡ Performance & Resource Optimizations

-   **Seamless Image → Video Unlock Crossfade**:
    -   Eliminates the black flash on lock screen dismissal via a two-phase reveal architecture.
    -   Instantly mounts a cached first-frame PNG (`live_wallpaper_fallback.png`) onto a top `CALayer` while the window is transparent (`alphaValue = 0`).
    -   Snaps window opacity to `1.0` before initiating a `CABasicAnimation` dissolve (0.7s) from still image to live video once `AVQueuePlayer` begins rendering.
-   **Zero Hardware Decoder Contention**:
    -   Listens to `NSWorkspace.willSleepNotification` *before* the display sleeps to proactively invoke `tearDown()` and unbind VideoToolbox hardware decoders before macOS WallpaperAgent initializes the lock screen player.
    -   Guards all `CATransaction` completion blocks with `isTornDown` flags to prevent memory leaks and zombie decoder callbacks on rapid lock/unlock cycles.
-   **Hardware-Accelerated HEVC (H.265) Transcoding**:
    -   Forces background conversion of non-compliant formats to `AVAssetExportPresetHEVCDeliverable` HEVC video streams, ensuring full compatibility with Apple Silicon hardware video decoders and macOS Tahoe lock screen requirements.
-   **Gapless Looping with Pure Video Composition**:
    -   Initializes `AVQueuePlayer` and `AVPlayerLooper` with video-only `AVMutableComposition` tracks, stripping all audio pipelines to prevent hardware audio clock synchronization pauses at loop boundaries.
-   **Intelligent Occlusion & Power Saver**:
    -   **Window Occlusion Detection**: Polls window levels (`kCGWindowListOptionOnScreenOnly`) to detect when the desktop is completely covered by full-screen apps or maximized windows, automatically pausing playback to drop CPU/GPU usage to 0%.
    -   **Low Power Mode Detection**: Subscribes to `ProcessInfo.processInfo.isLowPowerModeEnabled` and pauses playback when battery saving is active.
-   **Asynchronous Thumbnail Engine with NSCache**:
    -   Offloads `AVAssetImageGenerator` frame extraction to a concurrent `DispatchQueue.global(qos: .userInitiated)` background queue.
    -   Caches thumbnails in memory via `NSCache<NSURL, NSImage>` with automatic system memory pressure eviction, preventing UI thread micro-stutters during library scrolling.
-   **TCC Sandbox Storage Isolation**:
    -   Automatically clones user-selected video files into `~/Library/Application Support/com.example.LiveWallpaper/Library/` to prevent macOS TCC permission drops across reboots.

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/dashboard.png" width="48%" alt="Live Wallpaper Dashboard"/>
  <img src="screenshots/library.png" width="48%" alt="Wallpaper Storage Library"/>
</p>
<p align="center">
  <img src="screenshots/settings.png" width="48%" alt="Engine Playback Settings"/>
  <img src="screenshots/downloader.png" width="48%" alt="YouTube Downloader Interface"/>
</p>

---

## 🛠️ Technologies Used

-   **[Swift 6+](https://swift.org/)** — Primary language with strict concurrency and modern language features
-   **[AppKit](https://developer.apple.com/documentation/appkit)** — Low-level macOS window server management (`NSWindow`, `NSScreen`, `NSStatusItem`)
-   **[SwiftUI](https://developer.apple.com/xcode/swiftui/)** — Modern declarative settings panel, glassmorphic views, and reactive state management
-   **[AVFoundation](https://developer.apple.com/av-foundation/)** — Video queue management, `AVPlayerLooper`, `AVMutableComposition`, and `AVAssetImageGenerator`
-   **[VideoToolbox](https://developer.apple.com/documentation/videotoolbox)** — Hardware-accelerated H.265 / HEVC decoding and encoding pipelines
-   **[CoreGraphics & Quartz](https://developer.apple.com/documentation/coregraphics)** — Desktop window level layering (`kCGDesktopWindowLevel`) and occlusion window server inspection
-   **[ServiceManagement](https://developer.apple.com/documentation/servicemanagement)** — Background login item registration via `SMAppService`
-   **[UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)** — Native type-safe drag-and-drop file handling

---

## 📦 Installation & Building

### Prerequisites

-   macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or macOS 26.0 (Tahoe)
-   Xcode 15.0+ or Apple Command Line Tools (`swiftc` 6.0+)
-   *(Optional)* `yt-dlp` and `ffmpeg` installed for YouTube downloading capabilities (`brew install yt-dlp ffmpeg`)

### Build Steps

1. **Clone the repository**

    ```bash
    git clone https://github.com/shenmareparas/live-wallpaper.git
    cd live-wallpaper
    ```

2. **Compile the native application**

    ```bash
    chmod +x build.sh
    ./build.sh
    ```

3. **Launch the application**

    ```bash
    open LiveWallpaper.app
    ```

4. **Build the Professional Installer DMG** *(Optional)*

    ```bash
    chmod +x make_dmg.sh
    ./make_dmg.sh
    ```

---

## 📁 Project Structure

```
live-wallpaper/
├── main.swift                      # NSApplicationDelegate entrypoint, status bar menu, sleep/lock observers
├── SettingsView.swift               # SwiftUI Settings & Dashboard panel, Library grid, YouTube downloader
├── WallpaperWindow.swift           # Borderless desktop overlay window, AVPlayerLayer, occlusion & unlock crossfade
├── Info.plist                      # Application bundle config (LSUIElement = true for menu-bar stealth mode)
├── entitlements.plist              # Code signing entitlements and sandbox configuration
├── build.sh                        # Automated build, asset catalog compilation, and code signing script
├── make_dmg.sh                     # DMG installer generator wrapping local DMGMaker suite
├── App Icon.png                    # High-resolution application master icon
├── AppIcon.icns                    # Multi-resolution macOS icon bundle (16x16 up to 512x512@2x)
├── Menu Icon.svg                   # Dynamic resolution-independent status bar template icon
├── Media.xcassets/                 # Xcode Asset Catalog containing template vectors and app icons
├── project_documentation.md        # Comprehensive internal engineering architecture and technical notes
└── dmg_maker/                      # Standalone Swift Package for generating glassmorphic installer DMGs
    ├── Package.swift               # Swift Package Manager manifest
    └── Sources/DMGMaker/           # DMG generator CLI source code and visual assets
```

---

## 🧠 Architecture & Technical Deep-Dive

### 1. Wallpaper Window Server Hierarchy
`WallpaperWindow` creates a borderless `NSWindow` mapped to each connected `NSScreen`. The window is placed precisely behind desktop icons and ahead of the system wallpaper plane:
```swift
self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .canJoinAllApplications]
self.ignoresMouseEvents = true
```

### 2. Hardware Decoder Lifecycle & Lock Screen Synchronization
Playing background video overlays while macOS locks or sleeps causes VideoToolbox contention with the secure lock screen renderer. `Live Wallpaper` implements a three-tiered lifecycle observer:

```
[System Sleep / Lock Triggered]
              │
              ▼
   NSWorkspace.willSleepNotification (Fires BEFORE display sleeps)
              │
              ▼
   WallpaperWindow.tearDown()
   ├── currentPlayer.pause()
   ├── cancelPendingPrerolls()
   ├── layer.player = nil (Sever VideoToolbox surface)
   ├── replaceCurrentItem(with: nil)
   └── layer.removeFromSuperlayer()
              │
              ▼
   [System Lock Screen Plays HEVC via WallpaperAgent]
              │
              ▼
   DistributedNotification: com.apple.screenIsUnlocked
              │
              ▼
   Recreate WallpaperWindow (alphaValue = 0)
   ├── Mount first-frame thumbnail CALayer
   ├── Snap alphaValue to 1.0 (First visible pixel is crisp image)
   ├── Start AVQueuePlayer playback underneath
   ├── CABasicAnimation fade-out thumbnail layer over 0.7s
   └── Delayed restartWallpaperAgent() at t=2.0s (Fresh session for next lock)
```

### 3. Gapless Looping Pipeline
Standard `AVPlayerItemDidPlayToEndTimeNotification` seeking introduces perceptible 100–300ms frame stutter at loop boundaries. `Live Wallpaper` bypasses this entirely:
1. Strips all audio tracks using `AVMutableComposition` to prevent hardware clock synchronization wait states.
2. Initializes an empty `AVQueuePlayer()`.
3. Delegates queue treadmill operations to `AVPlayerLooper(player:templateItem:)` for continuous, zero-allocation video looping.

---

## ⚙️ Configuration & Preferences

Preferences are automatically synchronized using `UserDefaults` and `AppStorage`:

| Key | Type | Default | Description |
|---|---|---|---|
| `videoPath` | `String` | `""` | Absolute path to the currently active video in Application Support |
| `playbackSpeed` | `Double` | `1.0` | Video playback rate multiplier (0.5x – 2.0x) |
| `transitionDuration` | `Double` | `0.5` | Duration of crossfade animations between video changes (seconds) |
| `shuffleEnabled` | `Bool` | `false` | Enables automatic scheduled wallpaper rotation |
| `shuffleInterval` | `Double` | `300.0` | Interval between wallpaper shuffles (seconds) |
| `youtubeURLs` | `[String: String]` | `[:]` | Dictionary mapping local video filenames to original YouTube URLs |

---

## 🎯 Usage

1. **Launch the App**: Open `Live Wallpaper` from your Applications folder or menu bar.
2. **Add Wallpapers**: Drag and drop any video file into the **Wallpaper** tab, or paste a YouTube URL to download.
3. **Apply Wallpaper**: Click on any wallpaper card in your library to set it as your active desktop and lock screen background.
4. **Configure Playback**: Adjust playback speed, transition timing, or enable automatic shuffling in the **Settings** tab.
5. **Dashboard Monitor**: Check real-time rendering metrics, active monitor geometries, and power modes in the **Dashboard**.

---

## 🤝 Contributing

Contributions are welcome! If you'd like to improve Live Wallpaper:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Paras Shenmare**

-   GitHub: [@shenmareparas](https://github.com/shenmareparas)
-   Portfolio: [shenmareparas.com](https://shenmareparas.com)

---

## 🙏 Acknowledgments

-   Apple VideoToolbox and AVFoundation engineering teams
-   Open-source creators of `yt-dlp` and `ffmpeg`
-   The macOS developer community for insights into Sonoma/Sequoia/Tahoe wallpaper store mechanics

---

## 📞 Support

If you encounter any issues or have suggestions, please [open an issue](https://github.com/shenmareparas/live-wallpaper/issues).

---

<p align="center">
  ⭐ <b>If you like this project, please give it a star on GitHub!</b> ⭐
</p>
