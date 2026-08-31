import SwiftUI

// Custom UI helper for drag & drop visual feedback
struct ZCornerRectangle<Content: View>: View {
    var isDragging: Bool
    var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
                .background(isDragging ? Color.accentColor.opacity(0.04) : Color.primary.opacity(0.01))
                .cornerRadius(12)
            
            content()
        }
    }
}
