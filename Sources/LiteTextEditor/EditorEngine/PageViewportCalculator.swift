import AppKit

struct PageViewportCalculator {
    static func stableCenter(for visibleRect: NSRect, pageFrame: NSRect) -> NSPoint {
        NSPoint(
            x: visibleRect.width >= pageFrame.width
                ? pageFrame.midX
                : min(max(visibleRect.midX, pageFrame.minX), pageFrame.maxX),
            y: visibleRect.height >= pageFrame.height
                ? pageFrame.midY
                : min(max(visibleRect.midY, pageFrame.minY), pageFrame.maxY)
        )
    }

    static func clampedVisibleOrigin(
        centeredAt center: NSPoint,
        visibleSize: NSSize,
        documentBounds: NSRect
    ) -> NSPoint {
        let proposedOrigin = NSPoint(
            x: center.x - (visibleSize.width / 2),
            y: center.y - (visibleSize.height / 2)
        )
        let maxOrigin = NSPoint(
            x: max(documentBounds.minX, documentBounds.maxX - visibleSize.width),
            y: max(documentBounds.minY, documentBounds.maxY - visibleSize.height)
        )

        return NSPoint(
            x: min(max(proposedOrigin.x, documentBounds.minX), maxOrigin.x),
            y: min(max(proposedOrigin.y, documentBounds.minY), maxOrigin.y)
        )
    }
}
