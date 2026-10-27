import SwiftUI
import UniformTypeIdentifiers

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
    
    @State private var searchQuery: String = ""
    @State private var showYTDownloadSheet = false
    
    private var filteredWallpapers: [URL] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return importedWallpapers
        }
        return importedWallpapers.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        Group {
            if importedWallpapers.isEmpty {
                ContentUnavailableView {
                    Label("No Wallpapers in Library", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Drop MP4 or MOV video files here, or use the Add button in the toolbar.")
                } actions: {
                    Button(action: selectVideoFile) {
                        Label("Import Video File...", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if filteredWallpapers.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(filteredWallpapers, id: \.self) { url in
                            WallpaperLibraryCard(
                                url: url,
                                isActive: videoPath == url.path,
                                onApply: { selectWallpaper(url) },
                                onDelete: { deleteWallpaper(url) }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search wallpapers")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: selectVideoFile) {
                        Label("Import Video File...", systemImage: "plus.viewfinder")
                    }
                    .keyboardShortcut("o", modifiers: [.command])
                    
                    Button(action: { showYTDownloadSheet = true }) {
                        Label("Download from YouTube...", systemImage: "play.rectangle.fill")
                    }
                } label: {
                    Label("Add Wallpaper", systemImage: "plus")
                }
                .help("Add video wallpaper to library")
                .popover(isPresented: $showYTDownloadSheet, arrowEdge: .bottom) {
                    YouTubeDownloaderSection(
                        ytURL: $ytURL,
                        isDownloadingYT: $isDownloadingYT,
                        ytDownloadError: $ytDownloadError,
                        ytDownloadProgress: $ytDownloadProgress,
                        downloadYouTubeVideo: downloadYouTubeVideo
                    )
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        onVideoDropped(url.path)
                    }
                }
            }
            return true
        }
        .overlay {
            if isDraggingOver {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.05))
                    .allowsHitTesting(false)
            }
        }
    }
}
