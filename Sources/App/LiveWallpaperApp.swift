import SwiftUI
import AppKit

@main
struct LiveWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Live Wallpaper Settings")
        }
    }
}
