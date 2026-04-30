import AppKit

extension EditorController {
    var minimumZoomMagnification: Double {
        Double(minimumZoom)
    }

    var maximumZoomMagnification: Double {
        Double(maximumZoom)
    }

    func zoomIn() {
        stepZoom(direction: 1)
    }

    func zoomOut() {
        stepZoom(direction: -1)
    }

    func fitPageToScreen() {
        setZoomPreset(.fitPage)
    }

    func actualSize() {
        setZoomPreset(.actualSize)
    }

    func setZoomMagnification(_ magnification: Double) {
        selectedZoomPreset = matchingPreset(for: CGFloat(magnification)) ?? .actualSize
        applyZoom(CGFloat(magnification))
    }

    func setZoomPreset(_ preset: DocumentZoomPreset) {
        if selectedZoomPreset != preset {
            selectedZoomPreset = preset
        }

        if preset == .fitPage {
            applyZoom(fitPageMagnification())
            return
        }

        applyZoom(preset.magnification ?? 1)
    }

    func refreshZoomForLayout() {
        if selectedZoomPreset == .fitPage {
            applyZoom(fitPageMagnification(), shouldResizePages: false)
        } else if let scrollView {
            updateZoomDisplayText(for: scrollView.magnification)
        }
    }

    func configureZoomForCurrentScrollView() {
        guard let scrollView else { return }

        scrollView.allowsMagnification = true
        scrollView.minMagnification = minimumZoom
        scrollView.maxMagnification = maximumZoom
        setZoomPreset(selectedZoomPreset)
    }

    private func stepZoom(direction: Int) {
        let current = scrollView?.magnification
            ?? selectedZoomPreset.magnification
            ?? fitPageMagnification()

        let nextPreset: DocumentZoomPreset?

        if direction > 0 {
            nextPreset = DocumentZoomPreset.fixedPresets.first {
                ($0.magnification ?? 1) > current + 0.01
            }
        } else {
            nextPreset = DocumentZoomPreset.fixedPresets.reversed().first {
                ($0.magnification ?? 1) < current - 0.01
            }
        }

        if let nextPreset {
            setZoomPreset(nextPreset)
        }
    }

    private func fitPageMagnification() -> CGFloat {
        guard let scrollView else { return 1 }

        let availableWidth = max(
            scrollView.contentSize.width - (AutocompleteTextView.deskPadding * 2),
            AutocompleteTextView.paperWidth * minimumZoom
        )
        let availableHeight = max(
            scrollView.contentSize.height - (AutocompleteTextView.deskPadding * 2),
            AutocompleteTextView.pageHeight * minimumZoom
        )
        let widthFit = availableWidth / AutocompleteTextView.paperWidth
        let heightFit = availableHeight / AutocompleteTextView.pageHeight

        return min(widthFit, heightFit)
    }

    private func applyZoom(_ magnification: CGFloat, shouldResizePages: Bool = true) {
        let clampedMagnification = min(max(magnification, minimumZoom), maximumZoom)
        updateZoomDisplayText(for: clampedMagnification)

        guard let scrollView, let textView else { return }

        if abs(scrollView.magnification - clampedMagnification) > 0.001 {
            scrollView.setMagnification(clampedMagnification, centeredAt: pageAnchoredZoomCenter())
        }

        if shouldResizePages {
            textView.resizeForCachedPages()
        }

        keepPageVisible()
    }

    private func pageAnchoredZoomCenter() -> NSPoint {
        guard let scrollView, let textView else { return .zero }

        let visibleRect = scrollView.contentView.documentVisibleRect
        let pageFrame = textView.currentPageStackFrame

        guard pageFrame.intersects(visibleRect) else {
            return NSPoint(x: pageFrame.midX, y: pageFrame.midY)
        }

        return pageStableCenter(for: visibleRect, pageFrame: pageFrame)
    }

    private func keepPageVisible() {
        guard let scrollView, let textView else { return }

        let clipView = scrollView.contentView
        let visibleRect = clipView.documentVisibleRect
        let pageFrame = textView.currentPageStackFrame
        let targetCenter = pageFrame.intersects(visibleRect)
            ? pageStableCenter(for: visibleRect, pageFrame: pageFrame)
            : NSPoint(x: pageFrame.midX, y: pageFrame.midY)

        let targetOrigin = clampedVisibleOrigin(centeredAt: targetCenter, visibleSize: visibleRect.size, documentBounds: textView.bounds)

        guard abs(clipView.bounds.origin.x - targetOrigin.x) > 0.5
            || abs(clipView.bounds.origin.y - targetOrigin.y) > 0.5 else {
            return
        }

        clipView.scroll(to: targetOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func pageStableCenter(for visibleRect: NSRect, pageFrame: NSRect) -> NSPoint {
        NSPoint(
            x: visibleRect.width >= pageFrame.width
                ? pageFrame.midX
                : min(max(visibleRect.midX, pageFrame.minX), pageFrame.maxX),
            y: visibleRect.height >= pageFrame.height
                ? pageFrame.midY
                : min(max(visibleRect.midY, pageFrame.minY), pageFrame.maxY)
        )
    }

    private func clampedVisibleOrigin(centeredAt center: NSPoint, visibleSize: NSSize, documentBounds: NSRect) -> NSPoint {
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

    private func updateZoomDisplayText(for magnification: CGFloat) {
        let text = percentText(for: magnification)
        if zoomDisplayText != text {
            zoomDisplayText = text
        }

        let value = Double(magnification)
        if abs(zoomMagnification - value) > 0.001 {
            zoomMagnification = value
        }
    }

    private func percentText(for magnification: CGFloat) -> String {
        "\(Int((magnification * 100).rounded()))%"
    }

    private func matchingPreset(for magnification: CGFloat) -> DocumentZoomPreset? {
        DocumentZoomPreset.fixedPresets.first { preset in
            guard let presetMagnification = preset.magnification else { return false }
            return abs(presetMagnification - magnification) < 0.005
        }
    }
}
