import AppKit

extension AutocompleteTextView {
    struct PageDrawingStyle {
        static let cornerRadius: CGFloat = 2
        static let shadowBlurRadius: CGFloat = 12
        static let shadowXOffset: CGFloat = 0
        static let shadowYOffset: CGFloat = 2
        static let shadowAlpha: CGFloat = 0.11
        static let shadowOutset = shadowBlurRadius + max(abs(shadowXOffset), abs(shadowYOffset))
        static let maximumShadowAlpha = shadowAlpha
        static let blurredShadowPassCount = 1
        static let borderAlpha: CGFloat = 0.08
    }

    private static let pageShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(PageDrawingStyle.shadowAlpha)
        shadow.shadowOffset = NSSize(
            width: PageDrawingStyle.shadowXOffset,
            height: -PageDrawingStyle.shadowYOffset
        )
        shadow.shadowBlurRadius = PageDrawingStyle.shadowBlurRadius
        return shadow
    }()

    static func visualContentY(forContentY contentY: CGFloat) -> CGFloat {
        guard contentY > 0 else { return contentY }

        let pageIndex = floor(contentY / pageContentHeight)
        let contentYOnPage = contentY - (pageIndex * pageContentHeight)
        return (pageIndex * (pageHeight + pageGap)) + contentYOnPage
    }

    static func visualLineOriginY(forContentY contentY: CGFloat, usedHeight _: CGFloat) -> CGFloat {
        visualContentY(forContentY: contentY)
    }

    static func contentY(fromPotentialVisualY y: CGFloat) -> CGFloat {
        guard y > 0 else { return y }

        let visualPageStride = pageHeight + pageGap
        let visualPageIndex = floor(y / visualPageStride)

        guard visualPageIndex >= 1 else {
            return y
        }

        let yOnPage = y - (visualPageIndex * visualPageStride)
        return (visualPageIndex * pageContentHeight) + yOnPage
    }

    static func pageCount(forVisualContentHeight visualContentHeight: CGFloat) -> Int {
        let contentHeight = contentY(fromPotentialVisualY: max(visualContentHeight - 1, 0))
        return max(1, Int(floor(contentHeight / pageContentHeight)) + 1)
    }

    static func pageCount(forVisualLineOriginY visualLineOriginY: CGFloat) -> Int {
        let contentY = contentY(fromPotentialVisualY: max(visualLineOriginY, 0))
        return max(1, Int(floor(contentY / pageContentHeight)) + 1)
    }

    static func pageStackHeight(forPageCount pageCount: Int) -> CGFloat {
        let clampedPageCount = max(1, pageCount)
        return (CGFloat(clampedPageCount) * pageHeight) + (CGFloat(clampedPageCount - 1) * pageGap)
    }

    static func visiblePageRange(
        for dirtyRect: NSRect,
        pageOriginY: CGFloat,
        renderedPageCount: Int
    ) -> ClosedRange<Int>? {
        guard renderedPageCount > 0, !dirtyRect.isEmpty else { return nil }

        let shadowOutset = PageDrawingStyle.shadowOutset + abs(PageDrawingStyle.shadowYOffset)
        let pageStackMinY = pageOriginY - shadowOutset
        let pageStackMaxY = pageOriginY + pageStackHeight(forPageCount: renderedPageCount) + shadowOutset
        guard dirtyRect.maxY >= pageStackMinY, dirtyRect.minY <= pageStackMaxY else { return nil }

        let pageStride = pageHeight + pageGap
        let visibleMinY = max(dirtyRect.minY - pageOriginY - shadowOutset, 0)
        let visibleMaxY = max(dirtyRect.maxY - pageOriginY + shadowOutset, 0)
        let firstPage = max(0, Int(floor(visibleMinY / pageStride)))
        let lastVisiblePage = max(firstPage, Int(floor(visibleMaxY / pageStride)))
        let lastRenderedPage = renderedPageCount - 1
        let lastPage = min(lastVisiblePage, lastRenderedPage)

        guard firstPage <= lastPage else { return nil }
        return firstPage...lastPage
    }

    static func documentWidth(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        max(viewportWidth, paperWidth)
    }

    func resizeForCurrentPages() {
        pendingPageRefreshWorkItem?.cancel()
        pendingPageRefreshWorkItem = nil
        ensurePaperHeightFitsContent()
    }

    func resizeForCachedPages() {
        applyFrameSizeIfNeeded(targetFrameSize(forPageCount: renderedPageCount))
    }

    func prepareForUserScroll() {
        pendingPageRefreshWorkItem?.cancel()
        pendingPageRefreshWorkItem = nil
        updatePaperLayout()
        ensurePaperHeightFitsContent()
    }

    func moveInsertionPointToDocumentStartAndScrollToPageTop() {
        setSelectedRange(NSRange(location: 0, length: 0))
        scrollToPageTopCenteredHorizontally()

        DispatchQueue.main.async { [weak self] in
            self?.scrollToPageTopCenteredHorizontally()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.scrollToPageTopCenteredHorizontally()
        }
    }

    func updatePaperLayout() {
        let pageX = pageHorizontalOrigin(forBoundsWidth: bounds.width)
        let pageY = pageOriginY(forPageCount: renderedPageCount, boundsHeight: bounds.height)
        let containerSize = NSSize(width: Self.pageTextWidth, height: Self.textLayoutDimensionLimit)
        let inset = NSSize(
            width: pageX + Self.pageMargin,
            height: pageY + Self.pageMargin
        )

        textContainer?.widthTracksTextView = false
        if abs((textContainer?.containerSize.width ?? 0) - containerSize.width) > 0.5 {
            textContainer?.containerSize = containerSize
        }

        if abs(textContainerInset.width - inset.width) > 0.5 || abs(textContainerInset.height - inset.height) > 0.5 {
            textContainerInset = inset
        }

        if abs(lastPaperLayoutWidth - bounds.width) > 0.5 {
            lastPaperLayoutWidth = bounds.width
            needsDisplay = true
        }
    }

    func updatePagesAfterTextChange() {
        guard let pageCount = measuredPageCount() else { return }
        guard pageCount != renderedPageCount else { return }
        applyMeasuredPageCount(pageCount)
    }

    func schedulePageRefreshAfterTextChange() {
        pendingPageRefreshWorkItem?.cancel()

        let scheduledGeneration = contentGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingPageRefreshWorkItem = nil
            guard self.contentGeneration == scheduledGeneration else {
                self.schedulePageRefreshAfterTextChange()
                return
            }
            self.updatePagesAfterTextChange()
        }

        pendingPageRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pageRefreshDelay, execute: workItem)
    }

    func ensurePaperHeightFitsContent() {
        pendingPageRefreshWorkItem?.cancel()
        pendingPageRefreshWorkItem = nil
        guard let pageCount = measuredPageCount() else { return }
        applyMeasuredPageCount(pageCount)
    }

    func restoreVisibleOrigin(_ origin: NSPoint) {
        guard let scrollView = enclosingScrollView else { return }

        let clipView = scrollView.contentView
        let visibleSize = clipView.documentVisibleRect.size
        let maxOrigin = NSPoint(
            x: max(bounds.minX, bounds.maxX - visibleSize.width),
            y: max(bounds.minY, bounds.maxY - visibleSize.height)
        )
        let clampedOrigin = NSPoint(
            x: min(max(origin.x, bounds.minX), maxOrigin.x),
            y: min(max(origin.y, bounds.minY), maxOrigin.y)
        )

        guard abs(clipView.bounds.origin.x - clampedOrigin.x) > 0.5
            || abs(clipView.bounds.origin.y - clampedOrigin.y) > 0.5 else {
            return
        }

        clipView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    func centerPageHorizontallyPreservingVerticalPosition() {
        guard let scrollView = enclosingScrollView else { return }

        let visibleRect = scrollView.contentView.documentVisibleRect
        let pageFrame = currentPageStackFrame
        let proposedX = pageFrame.midX - (visibleRect.width / 2)
        let maxX = max(bounds.minX, bounds.maxX - visibleRect.width)
        let targetX = min(max(proposedX, bounds.minX), maxX)
        let targetY: CGFloat

        if pageFrame.intersects(visibleRect) {
            targetY = visibleRect.origin.y
        } else {
            let stableCenter = PageViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)
            targetY = PageViewportCalculator.clampedVisibleOrigin(
                centeredAt: stableCenter,
                visibleSize: visibleRect.size,
                documentBounds: bounds
            ).y
        }

        restoreVisibleOrigin(
            NSPoint(
                x: targetX,
                y: targetY
            )
        )
    }

    func drawPaperBackground(in dirtyRect: NSRect) {
        NSColor.liteTextEditorDesk.setFill()
        dirtyRect.fill()

        let pageX = pageHorizontalOrigin(forBoundsWidth: bounds.width)
        let pageY = pageOriginY(forPageCount: renderedPageCount, boundsHeight: bounds.height)
        let pageStride = Self.pageHeight + Self.pageGap

        guard let visiblePages = Self.visiblePageRange(
            for: dirtyRect,
            pageOriginY: pageY,
            renderedPageCount: renderedPageCount
        ) else { return }

        for pageIndex in visiblePages {
            let pageRect = NSRect(
                x: pageX,
                y: pageY + (CGFloat(pageIndex) * pageStride),
                width: Self.paperWidth,
                height: Self.pageHeight
            )

            let chromeRect = Self.pageChromeDrawRect(for: pageRect)
            guard chromeRect.intersects(dirtyRect), chromeRect.intersects(bounds) else { continue }

            Self.drawPageChrome(in: pageRect)
        }
    }

    static func pageChromeDrawRect(for pageRect: NSRect) -> NSRect {
        let shadowRect = pageRect
            .offsetBy(dx: PageDrawingStyle.shadowXOffset, dy: -PageDrawingStyle.shadowYOffset)
            .insetBy(dx: -PageDrawingStyle.shadowOutset, dy: -PageDrawingStyle.shadowOutset)
        return pageRect.insetBy(dx: -1, dy: -1).union(shadowRect)
    }

    private static func drawPageChrome(in pageRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: pageRect,
            xRadius: PageDrawingStyle.cornerRadius,
            yRadius: PageDrawingStyle.cornerRadius
        )

        NSGraphicsContext.saveGraphicsState()
        pageShadow.set()
        NSColor.white.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.setFill()
        path.fill()

        NSColor.black.withAlphaComponent(PageDrawingStyle.borderAlpha).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func keepInsertionPointVisible() {
        guard selectedRange().length == 0 else { return }
        scrollRangeToVisible(selectedRange())
    }

    func pageStackFrame(forPageCount pageCount: Int, boundsSize: NSSize) -> NSRect {
        NSRect(
            x: pageHorizontalOrigin(forBoundsWidth: boundsSize.width),
            y: pageOriginY(forPageCount: pageCount, boundsHeight: boundsSize.height),
            width: Self.paperWidth,
            height: Self.pageStackHeight(forPageCount: pageCount)
        )
    }

    func requestInitialFocusIfNeeded() {
        guard !didRequestInitialFocus else { return }
        didRequestInitialFocus = true

        moveInsertionPointToDocumentStartAndScrollToPageTop()

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
            self.scrollToPageTopCenteredHorizontally()
        }
    }

    private func targetFrameSize(forPageCount pageCount: Int) -> NSSize {
        let paddedPageStackHeight = Self.pageStackHeight(forPageCount: pageCount)
            + Self.pageTopVisiblePadding
            + Self.pageBottomVisiblePadding
        let viewportSize = enclosingScrollView?.contentSize ?? .zero
        let targetWidth = Self.documentWidth(
            forViewportWidth: viewportSize.width
        )
        let targetHeight = max(
            paddedPageStackHeight,
            viewportSize.height
        )

        return NSSize(width: targetWidth, height: targetHeight)
    }

    func invalidatePageMeasurementCache() {
        cachedPageMeasurementKey = nil
    }

    private func measuredPageCount() -> Int? {
        guard let layoutManager, let textContainer else { return nil }

        let measurementKey = PageMeasurementKey(
            contentGeneration: contentGeneration,
            stringLength: textStorageLength
        )

        if cachedPageMeasurementKey == measurementKey {
            return cachedMeasuredPageCount
        }

        if layoutManager.numberOfGlyphs > 0 {
            layoutManager.ensureLayout(forGlyphRange: NSRange(location: layoutManager.numberOfGlyphs - 1, length: 1))
        } else {
            layoutManager.ensureLayout(for: textContainer)
        }

        let pageCount = Self.pageCount(
            forVisualLineOriginY: maximumMeasuredVisualLineOriginY(
                layoutManager: layoutManager,
                textContainer: textContainer
            )
        )
        cachedPageMeasurementKey = measurementKey
        cachedMeasuredPageCount = pageCount
        return pageCount
    }

    private func maximumMeasuredVisualLineOriginY(
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> CGFloat {
        var maximumLineOriginY: CGFloat = 0
        let glyphCount = layoutManager.numberOfGlyphs

        if glyphCount > 0 {
            let lastLineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphCount - 1,
                effectiveRange: nil
            )
            maximumLineOriginY = max(maximumLineOriginY, lastLineRect.minY)
        }

        if hasTrailingNewlineForPageMeasurement,
           layoutManager.extraLineFragmentTextContainer === textContainer {
            maximumLineOriginY = max(maximumLineOriginY, layoutManager.extraLineFragmentRect.minY)
        }

        return maximumLineOriginY
    }

    private var hasTrailingNewlineForPageMeasurement: Bool {
        guard let lastScalar = string.unicodeScalars.last else { return true }
        return CharacterSet.newlines.contains(lastScalar)
    }

    private func applyFrameSizeIfNeeded(
        _ targetSize: NSSize,
        pageCountChanged: Bool = false,
        previousPageFrame: NSRect? = nil
    ) {
        let frameSizeChanged = abs(bounds.height - targetSize.height) > 1
            || abs(bounds.width - targetSize.width) > 1
            || abs(frame.height - targetSize.height) > 1
            || abs(frame.width - targetSize.width) > 1
        guard frameSizeChanged || pageCountChanged else { return }

        let visibleRect = enclosingScrollView?.contentView.documentVisibleRect
        let oldPageFrame = previousPageFrame ?? currentPageStackFrame
        let pageRelativeAnchor: NSPoint?

        if let visibleRect, oldPageFrame.intersects(visibleRect) {
            let anchor = PageViewportCalculator.stableCenter(
                for: visibleRect,
                pageFrame: oldPageFrame
            )
            pageRelativeAnchor = NSPoint(
                x: anchor.x - oldPageFrame.minX,
                y: anchor.y - oldPageFrame.minY
            )
        } else {
            pageRelativeAnchor = nil
        }

        if frameSizeChanged {
            super.setFrameSize(targetSize)
            setBoundsSize(targetSize)
        }
        updatePaperLayout()
        if pageCountChanged {
            needsDisplay = true
        }

        if let visibleRect, let pageRelativeAnchor {
            let newPageFrame = currentPageStackFrame
            let anchor = NSPoint(
                x: min(
                    max(newPageFrame.minX + pageRelativeAnchor.x, newPageFrame.minX),
                    newPageFrame.maxX
                ),
                y: min(
                    max(newPageFrame.minY + pageRelativeAnchor.y, newPageFrame.minY),
                    newPageFrame.maxY
                )
            )
            restoreVisibleOrigin(
                PageViewportCalculator.clampedVisibleOrigin(
                    centeredAt: anchor,
                    visibleSize: visibleRect.size,
                    documentBounds: bounds
                )
            )
        } else if let visibleRect {
            restoreVisibleOrigin(visibleRect.origin)
        }
    }

    private func applyMeasuredPageCount(_ pageCount: Int) {
        let pageCountChanged = pageCount != renderedPageCount
        let previousPageFrame = pageCountChanged ? currentPageStackFrame : nil
        renderedPageCount = pageCount

        applyFrameSizeIfNeeded(
            targetFrameSize(forPageCount: pageCount),
            pageCountChanged: pageCountChanged,
            previousPageFrame: previousPageFrame
        )
    }

    private func pageOriginY(forPageCount pageCount: Int, boundsHeight: CGFloat) -> CGFloat {
        max(
            Self.pageTopVisiblePadding,
            (boundsHeight - Self.pageStackHeight(forPageCount: pageCount)) / 2
        )
    }

    private func pageHorizontalOrigin(forBoundsWidth boundsWidth: CGFloat) -> CGFloat {
        max(0, (boundsWidth - Self.paperWidth) / 2)
    }

    private func scrollToPageTopCenteredHorizontally() {
        guard let scrollView = enclosingScrollView else { return }

        let visibleRect = scrollView.contentView.documentVisibleRect
        let pageFrame = currentPageStackFrame
        let proposedX = pageFrame.midX - (visibleRect.width / 2)
        let maxX = max(bounds.minX, bounds.maxX - visibleRect.width)
        restoreVisibleOrigin(
            NSPoint(
                x: min(max(proposedX, bounds.minX), maxX),
                y: max(bounds.minY, pageFrame.minY - Self.pageTopVisiblePadding)
            )
        )
    }
}
