import SwiftUI

struct YouTubeDownloaderSection: View {
    @Binding var ytURL: String
    @Binding var isDownloadingYT: Bool
    @Binding var ytDownloadError: String
    @Binding var ytDownloadProgress: String
    let downloadYouTubeVideo: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Download YouTube Video", systemImage: "play.rectangle.fill")
                .font(.headline)
            
            Text("Paste a YouTube link below. The video will be downloaded, converted to HEVC, and added to your wallpaper library.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 8) {
                TextField("https://www.youtube.com/watch?v=...", text: $ytURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDownloadingYT)
                
                if isDownloadingYT {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Downloading & Converting...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(ytDownloadProgress)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                        }
                        
                        let cleanPct = ytDownloadProgress.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                        if let pct = Double(cleanPct) {
                            ProgressView(value: pct, total: 100)
                                .progressViewStyle(.linear)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Button(action: {
                        downloadYouTubeVideo(ytURL)
                    }) {
                        HStack {
                            Spacer()
                            Label("Download and Add", systemImage: "arrow.down.circle")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(ytURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            if !ytDownloadError.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(ytDownloadError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
