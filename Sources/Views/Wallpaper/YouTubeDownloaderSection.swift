import SwiftUI

struct YouTubeDownloaderSection: View {
    @Binding var ytURL: String
    @Binding var isDownloadingYT: Bool
    @Binding var ytDownloadError: String
    @Binding var ytDownloadProgress: String
    let downloadYouTubeVideo: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                Text("Download YouTube Wallpaper")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            
            Text("Paste a YouTube link below. The video will be downloaded, optimized, and saved directly to your wallpaper library.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 8) {
                TextField("https://www.youtube.com/watch?v=...", text: $ytURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDownloadingYT)
                    .font(.system(size: 11))
                
                if isDownloadingYT {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Downloading...")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(ytDownloadProgress)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Start Download")
                            Spacer()
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ytURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            if !ytDownloadError.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(ytDownloadError)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}
