#!/bin/bash
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

if [ -z "$SDKROOT" ]; then
    if xcrun --show-sdk-path --sdk macosx >/dev/null 2>&1; then
        export SDKROOT=$(xcrun --show-sdk-path --sdk macosx)
    elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk" ]; then
        export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk"
    elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
        export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    fi
fi

echo "Generating DMG installer using DMGMaker..."
cd dmg_maker
swift run "DMG Maker" --app "../LiveWallpaper.app" --name "Live Wallpaper"
cd ..
echo "DMG created successfully: Live Wallpaper.dmg"
