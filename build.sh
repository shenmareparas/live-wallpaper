#!/bin/bash
set -e

echo "Building Live Wallpaper app..."

# Clean previous build
rm -rf LiveWallpaper.app

# Create bundle directories
mkdir -p LiveWallpaper.app/Contents/MacOS
mkdir -p LiveWallpaper.app/Contents/Resources

# Compile swift code
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
echo "Using SDK: $SDK_PATH"
swiftc -parse-as-library -o LiveWallpaper.app/Contents/MacOS/LiveWallpaper main.swift WallpaperWindow.swift SettingsView.swift -sdk "$SDK_PATH"

# Copy Info.plist and resources
cp Info.plist LiveWallpaper.app/Contents/Info.plist
cp AppIcon.icns LiveWallpaper.app/Contents/Resources/AppIcon.icns
cp "Menu Icon.svg" LiveWallpaper.app/Contents/Resources/MenuIcon.svg

# Compile Asset Catalog (compiles vector SVG for resolution-independent rendering)
xcrun actool Media.xcassets --compile LiveWallpaper.app/Contents/Resources --platform macosx --minimum-deployment-target 14.0

# Code sign the binary (Sandbox disabled)
/usr/bin/codesign -s - --force LiveWallpaper.app/Contents/MacOS/LiveWallpaper

echo "Build complete! Running 'open LiveWallpaper.app' to launch."
