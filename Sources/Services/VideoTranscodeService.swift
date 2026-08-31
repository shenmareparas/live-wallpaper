import Foundation
import AVFoundation

final class VideoTranscodeService {
    static let shared = VideoTranscodeService()
    
    private init() {}
    
    func ensureCompatibleVideo(at sourcePath: String, completion: @escaping (String) -> Void) {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 60)
        
        // Test if AVFoundation can decode the first frame
        if let _ = try? generator.copyCGImage(at: time, actualTime: nil) {
            completion(sourcePath)
            return
        }
        
        // If decoding failed, attempt transcode via fallback tools
        print("AVFoundation cannot directly decode \(sourcePath). Initiating fallback transcode...")
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.example.LiveWallpaper")
            .appendingPathComponent("Library")
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        
        let destinationURL = appSupportDir.appendingPathComponent(UUID().uuidString + ".mov")
        
        // Run background ffmpeg transcode if ffmpeg exists
        DispatchQueue.global(qos: .userInitiated).async {
            let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
            guard let ffmpegPath = ffmpegPaths.first(where: { fileManager.fileExists(atPath: $0) }) else {
                print("ffmpeg not found. Fallback transcode aborted.")
                DispatchQueue.main.async { completion(sourcePath) }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-y", "-i", sourcePath,
                "-c:v", "libx265", "-tag:v", "hvc1",
                "-an",
                destinationURL.path
            ]
            
            try? process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                if process.terminationStatus == 0 && fileManager.fileExists(atPath: destinationURL.path) {
                    print("Fallback transcode succeeded: \(destinationURL.path)")
                    completion(destinationURL.path)
                } else {
                    print("Fallback transcode failed. Using original file.")
                    completion(sourcePath)
                }
            }
        }
    }
    
    func convertMP4ToQuickTimeMOV(sourceURL: URL, destinationURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: sourceURL)
        
        // Strip audio tracks completely before transcoding
        let composition = AVMutableComposition()
        if let videoTrack = asset.tracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
            
            // Remove destination if it exists to avoid collisions
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Directly transcode to HEVC (H.265) using the video-only composition
            self.transcodeToHEVC(asset: composition, destinationURL: destinationURL, completion: completion)
        } else {
            // Fallback if no video tracks found
            try? FileManager.default.removeItem(at: destinationURL)
            self.transcodeToHEVC(asset: asset, destinationURL: destinationURL, completion: completion)
        }
    }
    
    func transcodeToHEVC(asset: AVAsset, destinationURL: URL, completion: @escaping (Bool) -> Void) {
        // Use HEVC (H.265) preset to satisfy strict macOS secure lock screen requirements
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: "AVAssetExportPresetHEVCDeliverable") else {
            completion(false)
            return
        }
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                print("Successfully transcoded video to native H.265/HEVC QuickTime MOV.")
                completion(true)
            } else {
                print("HEVC transcode failed: \(String(describing: exportSession.error))")
                completion(false)
            }
        }
    }
}
