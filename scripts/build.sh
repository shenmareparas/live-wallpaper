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

# Code sign the binary (Sandbox disabled)
/usr/bin/codesign -s - --force LiveWallpaper.app/Contents/MacOS/LiveWallpaper

echo "Build complete! Running 'open LiveWallpaper.app' to launch."
