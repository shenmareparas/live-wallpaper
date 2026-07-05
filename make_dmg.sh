#!/bin/bash
set -e

echo "Generating DMG installer using DMGMaker..."
cd dmg_maker
swift run "DMG Maker" --app "../LiveWallpaper.app" --name "Live Wallpaper"
cd ..
echo "DMG created successfully: Live Wallpaper.dmg"
