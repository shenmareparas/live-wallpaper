import AppKit
import AVFoundation

final class ThumbnailService {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSURL, NSImage>()
    
    private init() {
        cache.countLimit = 100
    }
    
    func cachedImage(for url: URL) -> NSImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func cacheImage(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    
    func getThumbnailURL(for videoURL: URL) -> URL {
        let fileManager = FileManager.default
        let thumbnailsDir = videoURL.deletingLastPathComponent().appendingPathComponent(".thumbnails")
        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)
        
        let thumbnailURL = thumbnailsDir.appendingPathComponent(videoURL.deletingPathExtension().lastPathComponent + ".png")
        
        if !fileManager.fileExists(atPath: thumbnailURL.path) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 60)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: thumbnailURL)
                }
            }
        }
        
        return thumbnailURL
    }
    
    func loadThumbnailAsync(for videoURL: URL, completion: @escaping (NSImage?) -> Void) {
        if let cached = cachedImage(for: videoURL) {
            completion(cached)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let thumbURL = self.getThumbnailURL(for: videoURL)
            if let image = NSImage(contentsOf: thumbURL) {
                self.cacheImage(image, for: videoURL)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
