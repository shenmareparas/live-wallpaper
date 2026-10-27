# macOS Golden Gate (macOS 27) Features

New and enhanced platform capabilities for macOS 27 (Golden Gate).

## Dynamic Wallpapers and WallpaperAgent Integration

macOS 27 (Golden Gate) continues the aerial video wallpaper architecture introduced in recent macOS versions with tighter integration and security constraints.

### Key Directory Locations

- User aerial database: `~/Library/Application Support/com.apple.wallpaper/aerials/`
- Video storage: `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`
- Thumbnail cache: `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`
- Manifest file: `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`

### Hardware Decoder Requirements

- Native secure lock-screen decoders require Apple Silicon hardware-accelerated HEVC (H.265 `hvc1` codec) QuickTime `.mov` files.
- H.264 video streams or non-HEVC formats can cause black screen lock-screen failures. Use `AVAssetExportPresetHEVCDeliverable` for transcoding.
- Transparent window overlays and VideoToolbox sessions must proactively clean up decoders before display sleep via `NSWorkspace.willSleepNotification`.

### WallpaperAgent Process Synchronization

When modifying wallpaper manifests programmatically:

```swift
import Foundation

func restartWallpaperAgent() {
    DispatchQueue.global(qos: .background).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent"]
        try? process.run()
        process.waitUntilExit()
    }
}
```

## Modern Window Management and Leveling

- Desktop window layering uses `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))`.
- Collection behaviors should include `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, and `.canJoinAllApplications`.
- Avoid calling `NSWorkspace.shared.setDesktopImageURL` during runtime as it overwrites WallpaperAgent video preferences.

## SwiftUI Updates for macOS 27

### onChange API Deprecations

In modern macOS versions (macOS 14 through macOS 27), the single-parameter `.onChange(of:perform:)` is deprecated. Use zero-argument or two-argument `(oldValue, newValue)` closures:

```swift
// Recommended: Zero-parameter action
.onChange(of: myState) {
    handleStateChange()
}

// Recommended: Two-parameter action
.onChange(of: myState) { oldValue, newValue in
    handleTransition(from: oldValue, to: newValue)
}
```

### Observation Framework

Prefer `@Observable` classes over `ObservableObject` and `@Published` when targeting macOS 14+:

```swift
import SwiftUI
import Observation

@Observable
final class WallpaperEngineState {
    var isPlaying: Bool = true
    var currentSpeed: Double = 1.0
}
```
