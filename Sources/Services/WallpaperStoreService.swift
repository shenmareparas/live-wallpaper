import AppKit
import AVFoundation

final class WallpaperStoreService {
    static let shared = WallpaperStoreService()
    
    private init() {}
    
    func saveSharedConfig(path: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configURL = homeDir.appendingPathComponent(".live_wallpaper_config.plist")
        let dict: [String: Any] = [
            "videoPath": path,
            "isMuted": true
        ]
        (dict as NSDictionary).write(to: configURL, atomically: true)
    }
    
    func registerInSystemWallpaperStore(videoPath: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let appSupportDir = libraryDir.appendingPathComponent("Application Support").appendingPathComponent("com.example.LiveWallpaper")
            let wallpaperDir = libraryDir.appendingPathComponent("Application Support").appendingPathComponent("com.apple.wallpaper")
            let aerialsDir = wallpaperDir.appendingPathComponent("aerials")
            let videosDir = aerialsDir.appendingPathComponent("videos")
            let thumbnailsDir = aerialsDir.appendingPathComponent("thumbnails")
            let manifestDir = aerialsDir.appendingPathComponent("manifest")
            let entriesURL = manifestDir.appendingPathComponent("entries.json")
            
            let categoryID = "LW000000-0000-4000-8000-000000000001"
            let subcategoryID = "LW000000-0000-4000-8000-000000000002"
            let assetID = "LW000000-0000-4000-8000-000000000003"
            
            let destinationVideoURL = videosDir.appendingPathComponent("\(assetID).mov")
            let destinationThumbnailURL = thumbnailsDir.appendingPathComponent("\(assetID).png")
            
            do {
                try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)
                
                // 1. Read entries.json
                guard fileManager.fileExists(atPath: entriesURL.path) else { return }
                let data = try Data(contentsOf: entriesURL)
                guard var entriesJson = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return }
                
                // 2. Helper to finalize database writes and WallpaperAgent restart
                let finishRegistration = { (success: Bool) in
                    guard var categories = entriesJson["categories"] as? [[String: Any]],
                          var assets = entriesJson["assets"] as? [[String: Any]] else { return }
                    
                    // Remove existing custom entries
                    categories.removeAll { ($0["id"] as? String) == categoryID }
                    assets.removeAll { ($0["id"] as? String) == assetID }
                    
                    // Prepend Category
                    let customCategory: [String: Any] = [
                        "id": categoryID,
                        "localizedDescriptionKey": "Custom Live Wallpaper",
                        "localizedNameKey": "Custom Live Wallpaper",
                        "preferredOrder": 0,
                        "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                        "representativeAssetID": assetID,
                        "subcategories": [
                            [
                                "id": subcategoryID,
                                "localizedDescriptionKey": "Custom Live Wallpaper",
                                "localizedNameKey": "Custom Live Wallpaper",
                                "preferredOrder": 0,
                                "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                                "representativeAssetID": assetID
                            ]
                        ]
                    ]
                    categories.insert(customCategory, at: 0)
                    entriesJson["categories"] = categories
                    
                    // Append Asset
                    let videoURLString = videoPath.isEmpty ? "" : "file://\(destinationVideoURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
                    let customAsset: [String: Any] = [
                        "accessibilityLabel": "Active Wallpaper Feed",
                        "categories": [categoryID],
                        "id": assetID,
                        "includeInShuffle": true,
                        "localizedNameKey": "Active Wallpaper Feed",
                        "pointsOfInterest": ["0": "CUSTOM_LW_0"],
                        "preferredOrder": 0,
                        "previewImage": "file://\(destinationThumbnailURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                        "shotID": "CUSTOM_LW",
                        "showInTopLevel": true,
                        "subcategories": [subcategoryID],
                        "url-4K-SDR-240FPS": videoURLString
                    ]
                    assets.append(customAsset)
                    entriesJson["assets"] = assets
                    
                    // Write back
                    do {
                        let updatedData = try JSONSerialization.data(withJSONObject: entriesJson, options: [.prettyPrinted])
                        try updatedData.write(to: entriesURL, options: [.atomic])
                        print("Successfully registered Live Wallpaper in system wallpaper store.")
                        
                        // Force refresh on main thread
                        DispatchQueue.main.async {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                            process.arguments = ["WallpaperAgent"]
                            try? process.run()
                        }
                    } catch {
                        print("Failed to write entries manifest: \(error)")
                    }
                }
                
                // 3. Handle Video & Thumbnail Copy/Creation
                if videoPath.isEmpty {
                    let placeholderImg = FallbackDesktopService.shared.createPlaceholderImage(size: NSSize(width: 1920, height: 1080))
                    
                    if let tiff = placeholderImg.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        // Write to system thumbnails folder
                        try pngData.write(to: destinationThumbnailURL)
                        
                        // Write to local application folder to use as desktop wallpaper
                        let localPlaceholderURL = appSupportDir.appendingPathComponent("placeholder_instructions.png")
                        try pngData.write(to: localPlaceholderURL)
                        
                        // Force set as desktop image immediately for all screens
                        DispatchQueue.main.async {
                            let workspace = NSWorkspace.shared
                            let screens = NSScreen.screens
                            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                                .allowClipping: true
                            ]
                            for screen in screens {
                                try? workspace.setDesktopImageURL(localPlaceholderURL, for: screen, options: options)
                            }
                        }
                    }
                    
                    finishRegistration(true)
                } else {
                    // Re-mux video to native QuickTime MOV asynchronously
                    let sourceURL = URL(fileURLWithPath: videoPath)
                    VideoTranscodeService.shared.convertMP4ToQuickTimeMOV(sourceURL: sourceURL, destinationURL: destinationVideoURL) { ok in
                        if ok {
                            finishRegistration(true)
                        } else {
                            // Fallback to direct raw copy if transcode fails entirely
                            print("Re-muxing failed completely. Falling back to direct raw copy...")
                            do {
                                try fileManager.copyItem(at: sourceURL, to: destinationVideoURL)
                                finishRegistration(true)
                            } catch {
                                print("Raw fallback copy also failed: \(error)")
                                finishRegistration(false)
                            }
                        }
                    }
                }
            } catch {
                print("Failed to register wallpaper in system store: \(error)")
            }
        }
    }
}
