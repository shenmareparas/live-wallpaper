import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if let iconImage = NSApplication.shared.applicationIconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 4) {
                Text("Live Wallpaper")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 1.1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("A lightweight, performance-focused macOS live video wallpaper engine that integrates seamlessly with Tahoe and Golden Gate WallpaperAgent sessions.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
            
            Divider()
                .frame(width: 200)
            
            VStack(spacing: 4) {
                Text("Developed for macOS 26 & macOS 27")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("© 2026 Paras Shenmare. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
