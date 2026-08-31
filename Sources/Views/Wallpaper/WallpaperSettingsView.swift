import SwiftUI

struct WallpaperSettingsView: View {
    @Binding var videoPath: String
    @Binding var launchAtLogin: Bool
    @Binding var isDraggingOver: Bool
    let selectVideoFile: () -> Void
    let toggleLaunchAtLogin: (Bool) -> Void
    let removeSelectedWallpaper: () -> Void
    let onVideoDropped: (String) -> Void
    
    let importedWallpapers: [URL]
    let selectWallpaper: (URL) -> Void
    let deleteWallpaper: (URL) -> Void
    let getThumbnailURL: (URL) -> URL
    
    @Binding var ytURL: String
    @Binding var isDownloadingYT: Bool
    @Binding var ytDownloadError: String
    @Binding var ytDownloadProgress: String
    let downloadYouTubeVideo: (String) -> Void
    
    @State private var showYTDownloadPopover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row with Plus Button
            HStack {
                Text("Wallpaper Library")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Spacer()
                
                Menu {
                    Button(action: selectVideoFile) {
                        Label("Import Video File...", systemImage: "plus.viewfinder")
                    }
                    Button(action: { showYTDownloadPopover = true }) {
                        Label("Download from YouTube...", systemImage: "play.rectangle.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
                .popover(isPresented: $showYTDownloadPopover, arrowEdge: .top) {
                    YouTubeDownloaderSection(
                        ytURL: $ytURL,
                        isDownloadingYT: $isDownloadingYT,
                        ytDownloadError: $ytDownloadError,
                        ytDownloadProgress: $ytDownloadProgress,
                        downloadYouTubeVideo: downloadYouTubeVideo
                    )
                }
            }
            
            // Library list
            if importedWallpapers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Library is empty. Click + to import or download.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(Color.primary.opacity(0.015))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
            } else {
                ScrollView {
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(importedWallpapers, id: \.self) { url in
                            WallpaperLibraryCard(
                                url: url,
                                isActive: videoPath == url.path,
                                onApply: { selectWallpaper(url) },
                                onDelete: { deleteWallpaper(url) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.isFileURL, ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async {
                        onVideoDropped(url.path)
                    }
                }
            }
            return true
        }
    }
}
