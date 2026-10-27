#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$DIR/Resources/bin"
TARGET_FILE="$BIN_DIR/yt-dlp"

mkdir -p "$BIN_DIR"

echo "Downloading latest standalone yt-dlp binary for macOS..."
curl -L -f "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$TARGET_FILE.fat"

echo "Extracting pure Apple Silicon (arm64) architecture..."
lipo -thin arm64 "$TARGET_FILE.fat" -output "$TARGET_FILE"
rm -f "$TARGET_FILE.fat"

chmod +x "$TARGET_FILE"

echo "yt-dlp (arm64) ready at $TARGET_FILE"
file "$TARGET_FILE"

