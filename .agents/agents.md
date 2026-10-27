# Agent Instructions and Guidelines

This file outlines instructions, architectural rules, and operational guidelines for AI agents working in the Live Wallpaper codebase.

---

## 1. Environment and Tooling Standards

* **JavaScript / TypeScript**: Always use Bun (`bun`, `bunx`). Do not use Node.js, npm, or npx.
* **Python**: Always use uv (`uv`, `uvx`) for package management and scripts.
* **macOS / iOS Development**: Xcode 27.1+, Apple Command Line Tools (`swiftc` 6.0+), CocoaPods via Homebrew.
* **Formatting**: Run formatting when applicable on completed code.
* **Safety**: Never execute `git commit`, `git push`, or destructive Git commands (`git reset --hard`, `git clean -f`) without explicit user permission.
* **Documentation**: Do not add emojis to any `.md` files.

---

## 2. Core Architecture Rules and Invariants

### Hardware Video Decoder Lifecycle
When tearing down or reinitializing `WallpaperWindow`:
1. Cancel pending prerolls: `currentPlayer?.cancelPendingPrerolls()`.
2. Unbind layer from player: `currentPlayerLayer?.player = nil`.
3. Clear current media item: `currentPlayer?.replaceCurrentItem(with: nil)`.
4. Remove layer from superlayer: `currentPlayerLayer?.removeFromSuperlayer()`.
5. Nil out references: `currentPlayer = nil`, `currentLooper = nil`, `currentPlayerLayer = nil`.

Failing to follow this teardown order causes VideoToolbox surface leaks and lock-screen decoder collisions.

### WallpaperAgent and Desktop Image Rules
* **Never call `NSWorkspace.shared.setDesktopImageURL` during the lock/unlock cycle or runtime playback.** Doing so overwrites macOS WallpaperAgent dynamic video preferences in the OS preferences database, breaking lock-screen live playback.
* **Static UUID Alignment**: Always use static asset identifier `"LW000000-0000-4000-8000-000000000003"` when writing to `manifest/entries.json` so System Settings maintains wallpaper selection across restarts.
* **HEVC Transcoding**: Lock-screen video sessions on macOS 26 Tahoe and macOS 27 Golden Gate require native H.265 (`hvc1`) HEVC streams. Always transcode via `VideoTranscodeService.swift`.

### Proactive Sleep Handling
* Handle display sleep proactively via `NSWorkspace.willSleepNotification` before the lock screen renders.
* Treat `com.apple.screenIsLocked` as a secondary fallback for keyboard lock events.

### Modern AVFoundation Concurrency and Task Cancellation
* **Async Asset Property Loading**: Use `loadTracks(withMediaType:)`, `load(.duration)`, and `load(.preferredTransform)` instead of deprecated synchronous accessors (`asset.tracks`, `asset.duration`, `videoTrack.preferredTransform`).
* **Task Cancellation Guarding**: Wrap player item preparation in `setupPlayerTask = Task { @MainActor in ... }` and cancel previous tasks in `setupPlayer()` and `tearDown()`. Always check `guard !Task.isCancelled, !self.isTornDown else { return }` prior to attaching sublayers or starting playback.

### SwiftUI Modern Patterns
* **Zero or Two-Argument `.onChange`**: Avoid deprecated single-argument `.onChange(of:perform:)`. Use `.onChange(of: value) { }` or `.onChange(of: value) { oldValue, newValue in }`.

---

## 3. Build and Test Verification

* **Building**: Run `./build.sh` (or `scripts/build.sh`).
* **Packaging**: Run `./make_dmg.sh` (or `scripts/make_dmg.sh`).
* **Sandboxing Note**: Swift macros and `swift-plugin-server` require process execution outside nested sandbox boundaries.

---

## 4. Context and Skills Navigation

* Full technical context, subsystem maps, and runbooks: Refer to `.agents/projectcontext.md`.
* macOS development guidelines, Swift 6+ patterns, Liquid Glass HIG, and API references: Refer to `.agents/skills/macos-development/SKILL.md`.

