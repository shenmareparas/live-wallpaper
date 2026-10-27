import Foundation

final class YouTubeDownloaderService {
    static let shared = YouTubeDownloaderService()
    
    private init() {}
    
    func locateYTDLP() -> String? {
        let fm = FileManager.default

        // 1. Check in the application bundle's auxiliary executables (Contents/MacOS/yt-dlp)
        if let bundleExecPath = Bundle.main.path(forAuxiliaryExecutable: "yt-dlp"), fm.isExecutableFile(atPath: bundleExecPath) {
            return bundleExecPath
        }

        // 2. Check in the application bundle's Resources directory
        if let resourcePath = Bundle.main.path(forResource: "yt-dlp", ofType: nil), fm.isExecutableFile(atPath: resourcePath) {
            return resourcePath
        }

        // 3. Fallback to common system installation paths
        let paths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/yt-dlp"
        ]
        for path in paths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yt-dlp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty, fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    func download(
        urlStr: String,
        onProgress: @escaping (String) -> Void,
        onCompletion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(),
              host.contains("youtube.com") || host.contains("youtu.be") else {
            onCompletion(.failure(NSError(domain: "YouTubeDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid YouTube URL"])))
            return
        }
        
        guard let ytDlpPath = locateYTDLP() else {
            onCompletion(.failure(NSError(domain: "YouTubeDownloader", code: 2, userInfo: [NSLocalizedDescriptionKey: "yt-dlp is not available. Please reinstall Live Wallpaper or install yt-dlp via Homebrew: brew install yt-dlp"])))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let appSupportLibraryDir = libraryDir.appendingPathComponent("Application Support")
                                                .appendingPathComponent("com.example.LiveWallpaper")
                                                .appendingPathComponent("Library")
            
            do {
                try fileManager.createDirectory(at: appSupportLibraryDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    onCompletion(.failure(error))
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = [
                "-f", "bestvideo[vcodec^=avc1]/bestvideo",
                "-P", appSupportLibraryDir.path,
                urlStr
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            let fileHandle = pipe.fileHandleForReading
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    if let progressRange = output.range(of: "\\b\\d+(\\.\\d+)?%", options: .regularExpression) {
                        let percent = String(output[progressRange])
                        DispatchQueue.main.async {
                            onProgress(percent)
                        }
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                fileHandle.readabilityHandler = nil
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        // Find newest file
                        do {
                            let files = try fileManager.contentsOfDirectory(at: appSupportLibraryDir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
                            let sortedFiles = try files.map { fileURL -> (URL, Date) in
                                let values = try fileURL.resourceValues(forKeys: [.creationDateKey])
                                return (fileURL, values.creationDate ?? Date.distantPast)
                            }.sorted(by: { $0.1 > $1.1 })
                            
                            if let newest = sortedFiles.first?.0 {
                                var dict = UserDefaults.standard.dictionary(forKey: "youtubeURLs") as? [String: String] ?? [:]
                                dict[newest.lastPathComponent] = urlStr
                                UserDefaults.standard.set(dict, forKey: "youtubeURLs")
                                onCompletion(.success(newest))
                            } else {
                                onCompletion(.failure(NSError(domain: "YouTubeDownloader", code: 3, userInfo: [NSLocalizedDescriptionKey: "Downloaded file could not be located"])))
                            }
                        } catch {
                            onCompletion(.failure(error))
                        }
                    } else {
                        onCompletion(.failure(NSError(domain: "YouTubeDownloader", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Download failed (code \(process.terminationStatus))"])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    onCompletion(.failure(error))
                }
            }
        }
    }
}
