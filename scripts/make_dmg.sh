#!/bin/bash
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
fi

echo "Generating DMG installer using DMGMaker..."
cd dmg_maker
swift run "DMG Maker" --app "../LiveWallpaper.app" --name "Live Wallpaper"
cd ..
echo "DMG created successfully: Live Wallpaper.dmg"
