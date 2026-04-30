import AppKit

extension AutocompleteTextView {
    static func visualContentY(forContentY contentY: CGFloat) -> CGFloat {
        guard contentY > 0 else { return contentY }

        let pageIndex = floor(contentY / pageContentHeight)
        let contentYOnPage = contentY - (pageIndex * pageContentHeight)
        return (pageIndex * (pageHeight + pageGap)) + contentYOnPage
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

    func resizeForCurrentPages() {
        invalidatePageMeasurementCache()
        ensurePaperHeightFitsContent()
    }

    func resizeForCachedPages() {
        applyFrameSizeIfNeeded(targetFrameSize(forPageCount: renderedPageCount))
    }

    func prepareForUserScroll() {
        pendingPaperResize = false
        updatePaperLayout()
        ensurePaperHeightFitsContent()
    }

    func moveInsertionPointToDocumentStartAndScrollToPageTop() {
        setSelectedRange(NSRange(location: 0, length: 0))
        scrollToPageTop()

        DispatchQueue.main.async { [weak self] in
            self?.scrollToPageTop()
        }
    }

    func updatePaperLayout() {
        let pageX = max(Self.deskPadding, (bounds.width - Self.paperWidth) / 2)
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

    func ensurePaperHeightFitsContent() {
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

        guard abs(clipView.bounds.origin.x - clampedOrigin.x) > 0.5
            || abs(clipView.bounds.origin.y - clampedOrigin.y) > 0.5 else {
            return
        }

        clipView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    func drawPaperBackground(in dirtyRect: NSRect) {
        NSColor.liteTextEditorDesk.setFill()
        dirtyRect.fill()

        let pageX = max(Self.deskPadding, (bounds.width - Self.paperWidth) / 2)
        let pageY = pageOriginY(forPageCount: renderedPageCount, boundsHeight: bounds.height)
        let pageStride = Self.pageHeight + Self.pageGap
        let visibleMinY = max(dirtyRect.minY - pageY, 0)
        let visibleMaxY = max(dirtyRect.maxY - pageY, 0)
        let firstPage = max(0, Int(floor(visibleMinY / pageStride)))
        let lastVisiblePage = max(firstPage, Int(floor(visibleMaxY / pageStride)))
        let lastRenderedPage = max(0, renderedPageCount - 1)
        let lastPage = min(lastVisiblePage, lastRenderedPage)

        guard firstPage <= lastPage else {
            return
        }

        for pageIndex in firstPage...lastPage {
            let pageRect = NSRect(
                x: pageX,
                y: pageY + (CGFloat(pageIndex) * pageStride),
                width: Self.paperWidth,
                height: Self.pageHeight
            )

            guard pageRect.intersects(bounds) else { continue }

            let path = NSBezierPath(roundedRect: pageRect, xRadius: 2, yRadius: 2)

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = 14
            shadow.set()
            NSColor.white.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor.black.withAlphaComponent(0.08).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    func keepInsertionPointVisible() {
        guard selectedRange().length == 0 else { return }
        scrollRangeToVisible(selectedRange())
    }

    func pageStackFrame(forPageCount pageCount: Int, boundsSize: NSSize) -> NSRect {
        NSRect(
            x: max(Self.deskPadding, (boundsSize.width - Self.paperWidth) / 2),
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
            self.scrollToPageTop()
        }
    }

    private func targetFrameSize(forPageCount pageCount: Int) -> NSSize {
        let contentHeight = Self.pageStackHeight(forPageCount: pageCount) + (Self.deskPadding * 2)
        let viewportHeight = max(
            enclosingScrollView?.contentSize.height ?? 0,
            enclosingScrollView?.contentView.bounds.height ?? 0
        )
        let viewportWidth = max(
            enclosingScrollView?.contentSize.width ?? 0,
            enclosingScrollView?.contentView.bounds.width ?? 0,
            frame.width
        )
        let targetHeight = max(contentHeight, viewportHeight)
        let targetWidth = max(viewportWidth, Self.paperWidth + (Self.deskPadding * 2))

        return NSSize(width: targetWidth, height: targetHeight)
    }

    func invalidatePageMeasurementCache() {
        cachedPageMeasurementKey = nil
    }

    private func measuredPageCount() -> Int? {
        guard let layoutManager, let textContainer else { return nil }

        let measurementKey = PageMeasurementKey(
            contentGeneration: contentGeneration,
            stringLength: (string as NSString).length
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

    private func applyFrameSizeIfNeeded(_ targetSize: NSSize, pageCountChanged: Bool = false) {
        guard abs(frame.height - targetSize.height) > 1 || abs(frame.width - targetSize.width) > 1 else {
            if pageCountChanged {
                needsDisplay = true
            }
            return
        }

        let visibleOrigin = enclosingScrollView?.contentView.documentVisibleRect.origin
        super.setFrameSize(targetSize)
        updatePaperLayout()

        if let visibleOrigin {
            restoreVisibleOrigin(visibleOrigin)
        }
    }

    private func pageOriginY(forPageCount pageCount: Int, boundsHeight: CGFloat) -> CGFloat {
        Self.deskPadding
    }

    private func scrollToPageTop() {
        guard let scrollView = enclosingScrollView else { return }

        let clipView = scrollView.contentView
        let currentOrigin = clipView.documentVisibleRect.origin
        restoreVisibleOrigin(NSPoint(x: currentOrigin.x, y: bounds.minY))
    }
}
