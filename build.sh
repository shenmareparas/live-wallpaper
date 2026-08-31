#!/bin/bash
set -e

echo "Building Live Wallpaper app..."

# Clean previous build
rm -rf LiveWallpaper.app

# Create bundle directories
mkdir -p LiveWallpaper.app/Contents/MacOS
mkdir -p LiveWallpaper.app/Contents/Resources

# Compile swift code
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
else
    SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
fi
echo "Using SDK: $SDK_PATH"
swiftc -parse-as-library -target arm64-apple-macos14.0 -o LiveWallpaper.app/Contents/MacOS/LiveWallpaper main.swift WallpaperWindow.swift SettingsView.swift -sdk "$SDK_PATH"

# Copy Info.plist and resources
cp Info.plist LiveWallpaper.app/Contents/Info.plist
cp AppIcon.icns LiveWallpaper.app/Contents/Resources/AppIcon.icns
cp "Menu Icon.svg" LiveWallpaper.app/Contents/Resources/MenuIcon.svg

# Compile Asset Catalog if actool is available
if xcrun -find actool >/dev/null 2>&1; then
    xcrun actool Media.xcassets --compile LiveWallpaper.app/Contents/Resources --platform macosx --minimum-deployment-target 14.0
else
    echo "actool not found in active toolchain, skipping asset catalog compilation."
fi

# Code sign the binary (Sandbox disabled)
/usr/bin/codesign -s - --force LiveWallpaper.app/Contents/MacOS/LiveWallpaper

echo "Build complete! Running 'open LiveWallpaper.app' to launch."
