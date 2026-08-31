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
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 4) {
                Text("Live Wallpaper")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                Text("Version 1.1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("A performance-optimized macOS live video wallpaper engine that pauses during fullscreen tasks and sleep states.")
                .font(.system(size: 11, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Divider()
                .padding(.horizontal, 40)
            
            Text("© 2026 Paras Shenmare. All rights reserved.")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))
            
            Spacer()
        }
    }
}
