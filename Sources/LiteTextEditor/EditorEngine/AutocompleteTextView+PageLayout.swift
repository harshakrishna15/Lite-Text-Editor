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

    static func visualLineOriginY(forContentY contentY: CGFloat, usedHeight: CGFloat) -> CGFloat {
        guard contentY > 0 else { return contentY }

        let pageIndex = floor(contentY / pageContentHeight)
        let contentYOnPage = contentY - (pageIndex * pageContentHeight)
        let shouldMoveToNextPage = contentYOnPage > 0
            && contentYOnPage + max(usedHeight, 0) > pageContentHeight
        let adjustedContentY = shouldMoveToNextPage
            ? (pageIndex + 1) * pageContentHeight
            : contentY

        return visualContentY(forContentY: adjustedContentY)
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

    static func pageTopPadding(for magnification: CGFloat) -> CGFloat {
        documentPadding(forVisiblePadding: pageTopVisiblePadding, magnification: magnification)
    }

    static func pageBottomPadding(for magnification: CGFloat) -> CGFloat {
        documentPadding(forVisiblePadding: pageBottomVisiblePadding, magnification: magnification)
    }

    private static func documentPadding(forVisiblePadding visiblePadding: CGFloat, magnification: CGFloat) -> CGFloat {
        visiblePadding / max(magnification, 0.01)
    }

    func resizeForCurrentPages() {
        pendingPageRefreshWorkItem?.cancel()
        pendingPageRefreshWorkItem = nil
        ensurePaperHeightFitsContent()
    }

    func resizeForCachedPages() {
        applyFrameSizeIfNeeded(targetFrameSize(forPageCount: renderedPageCount))
    }

    func resizeForCachedPages(at magnification: CGFloat) {
        documentLayoutScale = min(max(magnification, 0.01), 10)
        applyFrameSizeIfNeeded(
            targetFrameSize(forPageCount: renderedPageCount, magnification: magnification),
            preservesVisibleOrigin: false
        )
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

        renderedPageCount = pageCount

        applyFrameSizeIfNeeded(
            targetFrameSize(forPageCount: pageCount),
            pageCountChanged: true
        )
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
        let oldRenderedPageCount = renderedPageCount
        renderedPageCount = pageCount

        applyFrameSizeIfNeeded(
            targetFrameSize(forPageCount: pageCount),
            pageCountChanged: oldRenderedPageCount != renderedPageCount
        )
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

        let physicalOrigin = NSPoint(
            x: clampedOrigin.x * documentLayoutScale,
            y: clampedOrigin.y * documentLayoutScale
        )
        guard abs(clipView.bounds.origin.x - physicalOrigin.x) > 0.5
            || abs(clipView.bounds.origin.y - physicalOrigin.y) > 0.5 else {
            return
        }

        if let paperScrollView = scrollView as? PaperScrollView {
            paperScrollView.performProgrammaticHorizontalScroll {
                clipView.scroll(to: physicalOrigin)
                scrollView.reflectScrolledClipView(clipView)
            }
        } else {
            clipView.scroll(to: physicalOrigin)
            scrollView.reflectScrolledClipView(clipView)
        }
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
            let stableCenter = ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)
            targetY = ZoomViewportCalculator.clampedVisibleOrigin(
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

    private func targetFrameSize(forPageCount pageCount: Int, magnification: CGFloat? = nil) -> NSSize {
        let layoutScale = magnification ?? documentLayoutScale
        let contentHeight = Self.pageStackHeight(forPageCount: pageCount)
            + Self.pageTopPadding(for: layoutScale)
            + Self.pageBottomPadding(for: layoutScale)
        let scale = max(
            min(layoutScale, Self.minimumStableCanvasMagnification),
            0.01
        )
        let viewportWidth = max(
            (enclosingScrollView?.contentSize.width ?? 0) / scale,
            (enclosingScrollView?.contentView.bounds.width ?? 0) / scale
        )
        let targetWidth = Self.documentWidth(forViewportWidth: viewportWidth)

        return NSSize(width: targetWidth, height: contentHeight)
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

        let pageCount = Self.pageCount(forVisualContentHeight: layoutManager.usedRect(for: textContainer).maxY)
        cachedPageMeasurementKey = measurementKey
        cachedMeasuredPageCount = pageCount
        return pageCount
    }

    private func applyFrameSizeIfNeeded(
        _ targetSize: NSSize,
        pageCountChanged: Bool = false,
        preservesVisibleOrigin: Bool = true
    ) {
        let targetFrameSize = NSSize(
            width: targetSize.width * documentLayoutScale,
            height: targetSize.height * documentLayoutScale
        )

        guard abs(bounds.height - targetSize.height) > 1
            || abs(bounds.width - targetSize.width) > 1
            || abs(frame.height - targetFrameSize.height) > 1
            || abs(frame.width - targetFrameSize.width) > 1 else {
            if pageCountChanged {
                needsDisplay = true
            }
            return
        }

        let visibleOrigin = preservesVisibleOrigin
            ? enclosingScrollView?.contentView.documentVisibleRect.origin
            : nil
        super.setFrameSize(targetFrameSize)
        setBoundsSize(targetSize)
        updatePaperLayout()

        if let visibleOrigin {
            restoreVisibleOrigin(visibleOrigin)
        }
    }

    private func pageOriginY(forPageCount pageCount: Int, boundsHeight: CGFloat) -> CGFloat {
        Self.pageTopPadding(for: documentLayoutScale)
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
                y: bounds.minY
            )
        )
    }
}
