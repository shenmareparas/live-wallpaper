import SwiftUI
import AppKit

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
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                Group {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.secondary.opacity(0.06)
                            Image(systemName: "video.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                                .font(.system(size: 18))
                        }
                    }
                }
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isActive ? Color.accentColor : (isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.08)),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                
                // Badges
                HStack(spacing: 4) {
                    if isActive {
                        Text("Active")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    if youtubeURL != nil {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(6)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onApply()
            }
            .onTapGesture {
                onApply()
            }
            
            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack {
                    if !fileSizeString.isEmpty {
                        Text(fileSizeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isHovered && !isActive {
                        Text("Click to Apply")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onApply) {
                Label("Set as Wallpaper", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            if let ytStr = youtubeURL, let yt = URL(string: ytStr) {
                Button(action: {
                    NSWorkspace.shared.open(yt)
                }) {
                    Label("Open YouTube Source", systemImage: "safari")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Wallpaper", systemImage: "trash")
            }
        }
        .onAppear {
            loadThumbnail()
            loadFileMetadata()
        }
    }
    
    private func loadThumbnail() {
        ThumbnailService.shared.loadThumbnailAsync(for: url) { image in
            self.thumbnailImage = image
        }
    }
    
    private func loadFileMetadata() {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            self.fileSizeString = formatter.string(fromByteCount: Int64(size))
        }
    }
}
