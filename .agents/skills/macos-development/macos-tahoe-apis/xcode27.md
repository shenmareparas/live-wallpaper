# Xcode 27 and Swift 6.4 Toolchain

Modern development tools, build configuration, and SDK compatibility for macOS 27 development.

## Swift 6.4 Concurrency and Language Mode

```swift
// Enable strict concurrency checking in Xcode or Swift Package Manager
// Build Settings > Swift Compiler - Upcoming Features > Strict Concurrency: Complete
// Swift Language Version: Swift 6
```

## Dynamic SDK Detection

Avoid hardcoding specific SDK version paths (e.g. `MacOSX26.sdk`) in custom build scripts. Swift 6.4 compilers on macOS 27 require compatible macOS 27 SDK headers. Use dynamic SDK detection:

```bash
#!/bin/bash
if [ -n "$SDKROOT" ]; then
    SDK_PATH="$SDKROOT"
elif xcrun --show-sdk-path --sdk macosx >/dev/null 2>&1; then
    SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
else
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
fi
```

## Swift Macros and Sandboxing

Swift macros (e.g., `@Observable`, `@State`, `#Preview`) run as out-of-process plugins executed by `swift-plugin-server`. When running compilation inside nested sandboxes, the plugin server's sandbox initialization can fail. Ensure build environments allow process spawning for macro executables.

## Deployment Target Best Practices

When targeting modern macOS versions with legacy compatibility:

- Minimum deployment target: `-target arm64-apple-macos14.0` (supports Sonoma, Sequoia, Tahoe, and Golden Gate).
- Use `#available(macOS 27.0, *)` guards for newly introduced platform-specific APIs.
