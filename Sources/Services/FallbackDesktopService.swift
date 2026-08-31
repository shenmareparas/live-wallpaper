import AppKit

final class FallbackDesktopService {
    static let shared = FallbackDesktopService()
    
    private init() {}
    
    func createPlaceholderImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background Gradient
        let rect = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(
            starting: NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0),
            ending: NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0)
        )
        gradient?.draw(in: rect, angle: 45)
        
        // Central Card
        let cardWidth: CGFloat = 840
        let cardHeight: CGFloat = 520
        let cardRect = NSRect(
            x: (size.width - cardWidth) / 2,
            y: (size.height - cardHeight) / 2,
            width: cardWidth,
            height: cardHeight
        )
        
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.03).set()
        path.fill()
        NSColor(white: 1.0, alpha: 0.08).set()
        path.lineWidth = 1.5
        path.stroke()
        
        // Draw Header Title inside Card
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: titleParagraph
        ]
        let titleText = "Welcome to Live Wallpaper"
        let titleRect = NSRect(x: cardRect.minX + 40, y: cardRect.maxY - 100, width: cardRect.width - 80, height: 50)
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Draw Subtitle
        let subParagraph = NSMutableParagraphStyle()
        subParagraph.alignment = .center
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6),
            .paragraphStyle: subParagraph
        ]
        let subText = "Follow these simple steps to activate the live desktop engine:"
        let subRect = NSRect(x: cardRect.minX + 40, y: cardRect.maxY - 140, width: cardRect.width - 80, height: 30)
        subText.draw(in: subRect, withAttributes: subAttributes)
        
        // Draw Step Items
        let stepX = cardRect.minX + 80
        var currentY = cardRect.maxY - 220
        
        let steps = [
            ("1", "Open Wallpaper Settings", "Click 'Open Native Settings...' in this app, or go to System Settings > Wallpaper."),
            ("2", "Find Custom Live Wallpaper", "Scroll down to locate and click the 'Custom Live Wallpaper' category."),
            ("3", "Select Active Wallpaper Feed", "Click on the 'Active Wallpaper Feed' card to activate your video stream.")
        ]
        
        for (num, title, desc) in steps {
            let circleRect = NSRect(x: stepX, y: currentY - 6, width: 28, height: 28)
            let circlePath = NSBezierPath(ovalIn: circleRect)
            NSColor.systemBlue.withAlphaComponent(0.15).set()
            circlePath.fill()
            NSColor.systemBlue.set()
            circlePath.lineWidth = 1.0
            circlePath.stroke()
            
            let numParagraph = NSMutableParagraphStyle()
            numParagraph.alignment = .center
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemBlue,
                .paragraphStyle: numParagraph
            ]
            num.draw(in: NSRect(x: circleRect.minX, y: circleRect.minY + 4, width: circleRect.width, height: 20), withAttributes: numAttr)
            
            let itemTitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let itemDescAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.5)
            ]
            
            title.draw(at: NSPoint(x: stepX + 44, y: currentY + 6), withAttributes: itemTitleAttr)
            desc.draw(at: NSPoint(x: stepX + 44, y: currentY - 12), withAttributes: itemDescAttr)
            
            currentY -= 90
        }
        
        // Draw Footer
        let footerParagraph = NSMutableParagraphStyle()
        footerParagraph.alignment = .center
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.3),
            .paragraphStyle: footerParagraph
        ]
        let footerText = "Note: Playback automatically pauses during fullscreen tasks and sleep states."
        let footerRect = NSRect(x: cardRect.minX + 40, y: cardRect.minY + 30, width: cardRect.width - 80, height: 20)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
        
        image.unlockFocus()
        return image
    }
}
