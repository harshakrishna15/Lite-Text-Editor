import AppKit

struct ZoomViewportCalculator {
    static func fitPageMagnification(
        contentSize: NSSize,
        minimumZoom: CGFloat,
        paperWidth: CGFloat = AutocompleteTextView.paperWidth,
        pageHeight: CGFloat = AutocompleteTextView.pageHeight,
        deskPadding: CGFloat = AutocompleteTextView.deskPadding
    ) -> CGFloat {
        let availableWidth = max(
            contentSize.width - (deskPadding * 2),
            paperWidth * minimumZoom
        )
        let availableHeight = max(
            contentSize.height - (deskPadding * 2),
            pageHeight * minimumZoom
        )
        let widthFit = availableWidth / paperWidth
        let heightFit = availableHeight / pageHeight

        return min(widthFit, heightFit)
    }

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

    static func clampedVisibleOrigin(centeredAt center: NSPoint, visibleSize: NSSize, documentBounds: NSRect) -> NSPoint {
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
