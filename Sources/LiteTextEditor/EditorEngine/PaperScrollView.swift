import AppKit

final class PaperClipView: NSClipView {
    var allowsProgrammaticHorizontalScroll = false

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrainedBounds = super.constrainBoundsRect(proposedBounds)

        if !allowsProgrammaticHorizontalScroll {
            constrainedBounds.origin.x = bounds.origin.x
        }

        return constrainedBounds
    }
}

final class PaperScrollView: NSScrollView {
    static let scrollerRevealEdgeInset: CGFloat = 28
    static let horizontalWheelTolerance: CGFloat = 0.5

    var didLayout: (() -> Void)?
    var onMagnifyGesture: ((CGFloat, NSEvent.Phase) -> Void)?
    private var pendingDocumentResize = false
    private var resizeGeneration = 0
    private var hasPreparedFirstScroll = false
    private var scrollerRevealTrackingArea: NSTrackingArea?
    private var didRecentlyFlashScrollers = false

    static func shouldRevealScrollers(for point: NSPoint, in bounds: NSRect, edgeInset: CGFloat = scrollerRevealEdgeInset) -> Bool {
        guard bounds.contains(point) else { return false }
        return point.x >= bounds.maxX - edgeInset || point.y <= bounds.minY + edgeInset
    }

    static func shouldIgnoreHorizontalOnlyWheel(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        abs(deltaX) > horizontalWheelTolerance && abs(deltaY) <= horizontalWheelTolerance
    }

    override func layout() {
        super.layout()
        resizeDocumentForCurrentViewport()
        didLayout?()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hasPreparedFirstScroll = false
        resizeDocumentForCurrentViewport()
        scheduleDocumentResize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        hasPreparedFirstScroll = false
        resizeDocumentForCurrentViewport()
        scheduleDocumentResize()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let scrollerRevealTrackingArea {
            removeTrackingArea(scrollerRevealTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        scrollerRevealTrackingArea = trackingArea
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let point = convert(event.locationInWindow, from: nil)
        if Self.shouldRevealScrollers(for: point, in: bounds) {
            revealScrollersForEdgeHover()
        } else {
            didRecentlyFlashScrollers = false
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        didRecentlyFlashScrollers = false
    }

    override func scrollWheel(with event: NSEvent) {
        if Self.shouldIgnoreHorizontalOnlyWheel(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY) {
            return
        }

        prepareDocumentForFirstScrollIfNeeded()
        let originalX = contentView.bounds.origin.x
        super.scrollWheel(with: event)
        restoreHorizontalOrigin(originalX)

        DispatchQueue.main.async { [weak self] in
            self?.restoreHorizontalOrigin(originalX)
        }
    }

    override func magnify(with event: NSEvent) {
        onMagnifyGesture?(event.magnification, event.phase)
    }

    private func scheduleDocumentResize() {
        guard !pendingDocumentResize else { return }
        pendingDocumentResize = true
        let generation = resizeGeneration

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.pendingDocumentResize, self.resizeGeneration == generation else { return }
            self.pendingDocumentResize = false
            (self.documentView as? AutocompleteTextView)?.resizeForCurrentPages()
            self.didLayout?()
        }
    }

    private func resizeDocumentForCurrentViewport() {
        (documentView as? AutocompleteTextView)?.resizeForCachedPages()
    }

    private func prepareDocumentForFirstScrollIfNeeded() {
        guard !hasPreparedFirstScroll || pendingDocumentResize else { return }
        hasPreparedFirstScroll = true
        resizeGeneration += 1
        pendingDocumentResize = false
        (documentView as? AutocompleteTextView)?.prepareForUserScroll()
        didLayout?()
    }

    private func restoreHorizontalOrigin(_ x: CGFloat) {
        guard abs(contentView.bounds.origin.x - x) > 0.5 else { return }

        performProgrammaticHorizontalScroll {
            contentView.scroll(to: NSPoint(x: x, y: contentView.bounds.origin.y))
            reflectScrolledClipView(contentView)
        }
    }

    func performProgrammaticHorizontalScroll(_ changes: () -> Void) {
        let paperClipView = contentView as? PaperClipView
        paperClipView?.allowsProgrammaticHorizontalScroll = true
        changes()
        paperClipView?.allowsProgrammaticHorizontalScroll = false
    }

    private func revealScrollersForEdgeHover() {
        guard !didRecentlyFlashScrollers else { return }
        didRecentlyFlashScrollers = true
        flashScrollers()
    }
}
