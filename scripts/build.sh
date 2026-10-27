#!/bin/bash
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

echo "Building Live Wallpaper app from Sources..."

# Clean previous build
rm -rf LiveWallpaper.app

# Create bundle directories
mkdir -p LiveWallpaper.app/Contents/MacOS
mkdir -p LiveWallpaper.app/Contents/Resources

# Collect all Swift source files
SWIFT_FILES=$(find Sources -name "*.swift" -type f)

# Select compatible SDK
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
echo "Using SDK: $SDK_PATH"

# Compile swift code
swiftc -parse-as-library -target arm64-apple-macos14.0 -o LiveWallpaper.app/Contents/MacOS/LiveWallpaper $SWIFT_FILES -sdk "$SDK_PATH"

# Copy Info.plist and resources
cp Resources/Info.plist LiveWallpaper.app/Contents/Info.plist
cp Resources/AppIcon.icns LiveWallpaper.app/Contents/Resources/AppIcon.icns
cp "Resources/Menu Icon.svg" LiveWallpaper.app/Contents/Resources/MenuIcon.svg

# Compile Asset Catalog if actool is available
if xcrun -find actool >/dev/null 2>&1 && [ -d "Resources/Media.xcassets" ]; then
    xcrun actool Resources/Media.xcassets --compile LiveWallpaper.app/Contents/Resources --platform macosx --minimum-deployment-target 14.0
else
    echo "actool not found in active toolchain, skipping asset catalog compilation."
fi

# Bundle standalone yt-dlp binary if available, or download it if missing
if [ ! -f "Resources/bin/yt-dlp" ]; then
    echo "yt-dlp binary not found in Resources/bin. Attempting to download..."
    if [ -x "scripts/download_ytdlp.sh" ]; then
        ./scripts/download_ytdlp.sh || echo "Warning: Could not download yt-dlp automatically. Building without bundled yt-dlp."
    fi
fi

if [ -f "Resources/bin/yt-dlp" ]; then
    echo "Bundling Apple Silicon (arm64) yt-dlp into LiveWallpaper.app/Contents/MacOS/..."
    if lipo -info "Resources/bin/yt-dlp" 2>/dev/null | grep -q "x86_64"; then
        lipo -thin arm64 "Resources/bin/yt-dlp" -output "LiveWallpaper.app/Contents/MacOS/yt-dlp"
    else
        cp "Resources/bin/yt-dlp" "LiveWallpaper.app/Contents/MacOS/yt-dlp"
    fi
    chmod +x "LiveWallpaper.app/Contents/MacOS/yt-dlp"
    /usr/bin/codesign -s - --force "LiveWallpaper.app/Contents/MacOS/yt-dlp"
fi

# Code sign the main binary (Sandbox disabled)
/usr/bin/codesign -s - --force LiveWallpaper.app/Contents/MacOS/LiveWallpaper

echo "Build complete! Running 'open LiveWallpaper.app' to launch."
