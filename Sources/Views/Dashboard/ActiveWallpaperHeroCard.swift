import SwiftUI
import AppKit

struct ActiveWallpaperHeroCard: View {
    let videoPath: String
    let activeThumbnailURL: URL?
    let fileSizeString: String
    let youtubeURL: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT WALLPAPER")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            if !videoPath.isEmpty {
                HStack(spacing: 12) {
                    // Thumbnail Preview
                    Group {
                        if let thumbURL = activeThumbnailURL, let nsImage = NSImage(contentsOf: thumbURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color.primary.opacity(0.03)
                                Image(systemName: "video.fill")
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                    }
                    .frame(width: 120, height: 68)
                    .cornerRadius(6)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    
                    // Metadata Info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(URL(fileURLWithPath: videoPath).lastPathComponent)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text("HEVC Video")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                            
                            if !fileSizeString.isEmpty {
                                Text(fileSizeString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Actions
                        HStack(spacing: 8) {
                            Button(action: {
                                NSWorkspace.shared.selectFile(videoPath, inFileViewerRootedAtPath: "")
                            }) {
                                Label("Reveal in Finder", systemImage: "folder.fill")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if let ytURLStr = youtubeURL, let ytURL = URL(string: ytURLStr) {
                                Button(action: {
                                    NSWorkspace.shared.open(ytURL)
                                }) {
                                    Label("Visit Source", systemImage: "safari.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .frame(height: 68)
                    
                    Spacer()
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Active Wallpaper")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Import or select a wallpaper from the Wallpaper library tab.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
    }
}
