import SwiftUI
import AppKit

struct ActiveWallpaperHeroCard: View {
    let videoPath: String
    let activeThumbnailURL: URL?
    let fileSizeString: String
    let youtubeURL: String?
    let isPlaying: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Wallpaper")
                .font(.headline)
            
            if !videoPath.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    // Thumbnail Preview
                    ZStack {
                        if let thumbURL = activeThumbnailURL, let nsImage = NSImage(contentsOf: thumbURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.secondary.opacity(0.08)
                            Image(systemName: "video.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 150, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    
                    // Metadata & Actions
                    VStack(alignment: .leading, spacing: 6) {
                        Text(URL(fileURLWithPath: videoPath).lastPathComponent)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            Text("HEVC Native")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                            
                            if !fileSizeString.isEmpty {
                                Text(fileSizeString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(isPlaying ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(isPlaying ? "Rendering" : "Paused")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                NSWorkspace.shared.selectFile(videoPath, inFileViewerRootedAtPath: "")
                            }) {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if let ytURLStr = youtubeURL, let ytURL = URL(string: ytURLStr) {
                                Button(action: {
                                    NSWorkspace.shared.open(ytURL)
                                }) {
                                    Label("Source Video", systemImage: "arrow.up.right.square")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .frame(height: 90)
                    
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 150, height: 90)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Wallpaper Configured")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Import a video file or select a wallpaper from your library.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }
}
