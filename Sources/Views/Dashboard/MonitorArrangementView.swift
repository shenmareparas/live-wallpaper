import SwiftUI
import AppKit

struct ScreenVisualizerView: View {
    var isPlaying: Bool
    var activeThumbnailURL: URL?
    
    var body: some View {
        let screens = NSScreen.screens
        let frames = screens.map { $0.frame }
        let minX = frames.map { $0.minX }.min() ?? 0
        let minY = frames.map { $0.minY }.min() ?? 0
        let maxX = frames.map { $0.maxX }.max() ?? 1
        let maxY = frames.map { $0.maxY }.max() ?? 1
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY
        
        let containerWidth: CGFloat = 160
        let containerHeight: CGFloat = 80
        let scale = min(containerWidth / totalWidth, containerHeight / totalHeight) * 0.8
        
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
            
            ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                let frame = screen.frame
                let w = frame.width * scale
                let h = frame.height * scale
                let x = (frame.minX - minX + (frame.width - totalWidth) / 2) * scale
                let y = -(frame.minY - minY + (frame.height - totalHeight) / 2) * scale
                
                VStack(spacing: 1) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.black)
                            .frame(width: w, height: h)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Group {
                            if isPlaying {
                                if let thumbURL = activeThumbnailURL, let nsImage = NSImage(contentsOf: thumbURL) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: w - 2, height: h - 2)
                        .cornerRadius(3)
                        .clipped()
                        
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(isPlaying ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                            .cornerRadius(2)
                    }
                    
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: max(4, w * 0.15), height: 4)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: max(8, w * 0.35), height: 1)
                }
                .offset(x: x, y: y)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
    }
}
