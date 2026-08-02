import AppKit

final class PaperScrollView: NSScrollView {
    static let scrollerRevealEdgeInset: CGFloat = 28
    static let horizontalWheelTolerance: CGFloat = 0.5

    var onViewportSizeChanged: (() -> Void)?
    private var pendingDocumentResize = false
    private var resizeGeneration = 0
    private var hasPreparedFirstScroll = false
    private var scrollerRevealTrackingArea: NSTrackingArea?
    private var didRecentlyFlashScrollers = false
    private var isDeferringDocumentResizeDuringLiveResize = false

    static func shouldRevealScrollers(
        for point: NSPoint,
        in bounds: NSRect,
        edgeInset: CGFloat = scrollerRevealEdgeInset
    ) -> Bool {
        guard bounds.contains(point) else { return false }
        return point.x >= bounds.maxX - edgeInset || point.y <= bounds.minY + edgeInset
    }

    static func shouldIgnoreHorizontalOnlyWheel(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        abs(deltaX) > horizontalWheelTolerance && abs(deltaY) <= horizontalWheelTolerance
    }

    static func shouldAllowHorizontalPanning(
        visibleDocumentWidth: CGFloat,
        pageWidth: CGFloat = AutocompleteTextView.paperWidth
    ) -> Bool {
        visibleDocumentWidth + horizontalWheelTolerance < pageWidth
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hasPreparedFirstScroll = false
        resizeDocumentForCurrentViewport()
        scheduleDocumentResize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousContentSize = contentSize
        super.setFrameSize(newSize)
        hasPreparedFirstScroll = false

        if !isDeferringDocumentResizeDuringLiveResize {
            resizeDocumentForCurrentViewport()
            scheduleDocumentResize()
        }

        if abs(previousContentSize.width - contentSize.width) > 0.5
            || abs(previousContentSize.height - contentSize.height) > 0.5 {
            onViewportSizeChanged?()
        }
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isDeferringDocumentResizeDuringLiveResize = true
        pendingDocumentResize = false
        resizeGeneration += 1
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isDeferringDocumentResizeDuringLiveResize = false
        resizeDocumentForCurrentViewport()
        scheduleDocumentResize()
        onViewportSizeChanged?()
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
        prepareDocumentForFirstScrollIfNeeded()

        if Self.shouldAllowHorizontalPanning(
            visibleDocumentWidth: contentView.documentVisibleRect.width
        ) {
            super.scrollWheel(with: event)
            return
        }

        if Self.shouldIgnoreHorizontalOnlyWheel(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY
        ) {
            return
        }

        let originalX = contentView.bounds.origin.x
        super.scrollWheel(with: event)
        let didDriftHorizontally = abs(contentView.bounds.origin.x - originalX) > 0.5
        restoreHorizontalOrigin(originalX)

        if didDriftHorizontally {
            DispatchQueue.main.async { [weak self] in
                self?.restoreHorizontalOrigin(originalX)
            }
        }
    }

    private func scheduleDocumentResize() {
        guard !isDeferringDocumentResizeDuringLiveResize else { return }
        guard !pendingDocumentResize else { return }
        pendingDocumentResize = true
        let generation = resizeGeneration

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.pendingDocumentResize, self.resizeGeneration == generation else { return }
            self.pendingDocumentResize = false
            (self.documentView as? AutocompleteTextView)?.resizeForCurrentPages()
            self.onViewportSizeChanged?()
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
    }

    private func restoreHorizontalOrigin(_ x: CGFloat) {
        guard abs(contentView.bounds.origin.x - x) > 0.5 else { return }

        contentView.scroll(to: NSPoint(x: x, y: contentView.bounds.origin.y))
        reflectScrolledClipView(contentView)
    }

    private func revealScrollersForEdgeHover() {
        guard !didRecentlyFlashScrollers else { return }
        didRecentlyFlashScrollers = true
        flashScrollers()
    }
}
