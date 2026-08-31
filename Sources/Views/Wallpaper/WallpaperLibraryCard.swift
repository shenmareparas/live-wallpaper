import SwiftUI
import AppKit
import AVFoundation

struct WallpaperLibraryCard: View {
    let url: URL
    let isActive: Bool
    let onApply: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage? = nil
    @State private var fileSizeString: String = ""
    
    private var youtubeURL: String? {
        let dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
        return dict[url.lastPathComponent]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 94)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    ZStack {
                        Color.primary.opacity(0.03)
                        Image(systemName: "video.fill")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 16))
                    }
                    .frame(height: 94)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                }
                
                // Hover Actions Overlay
                if isHovered || isActive {
                    Color.black.opacity(isActive ? 0.45 : 0.25)
                        .cornerRadius(8)
                    
                    VStack {
                        HStack {
                            if isActive {
                                Text("Active")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            Spacer()
                            
                            if let ytURLStr = youtubeURL, let ytURL = URL(string: ytURLStr) {
                                Button(action: {
                                    NSWorkspace.shared.open(ytURL)
                                }) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Open YouTube link")
                            }
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(6)
                        
                        Spacer()
                        
                        if !isActive {
                            Button(action: onApply) {
                                Text("Apply Wallpaper")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .shadow(color: .black.opacity(0.15), radius: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .frame(height: 94)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.green : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05)), lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: isActive ? Color.green.opacity(0.2) : (isHovered ? Color.black.opacity(0.08) : Color.clear), radius: isActive ? 6 : 3, x: 0, y: isActive ? 3 : 1)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(fileSizeString.isEmpty ? " " : fileSizeString)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadMetadataAndThumbnail()
        }
        .onChange(of: url) { _ in
            loadMetadataAndThumbnail()
        }
    }
    
    private func loadMetadataAndThumbnail() {
        let targetURL = url
        
        ThumbnailService.shared.loadThumbnailAsync(for: targetURL) { image in
            self.thumbnailImage = image
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let sizeStr = self.calculateSize(for: targetURL)
            DispatchQueue.main.async {
                self.fileSizeString = sizeStr
            }
        }
    }
    
    private func calculateSize(for targetURL: URL) -> String {
        var sizeStr = ""
        if let values = try? targetURL.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .file
            sizeStr = formatter.string(fromByteCount: Int64(size))
        }
        return sizeStr
    }
}
