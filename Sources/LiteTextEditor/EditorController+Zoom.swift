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
        let clampedMagnification = min(max(magnification, minimumZoomMagnification), maximumZoomMagnification)
        selectedZoomPreset = matchingPreset(for: CGFloat(clampedMagnification)) ?? .actualSize
        applyZoom(CGFloat(clampedMagnification))
    }

    func previewZoomMagnification(_ magnification: Double) {
        let clampedMagnification = min(max(magnification, minimumZoomMagnification), maximumZoomMagnification)
        selectedZoomPreset = matchingPreset(for: CGFloat(clampedMagnification)) ?? .actualSize
        applyZoom(CGFloat(clampedMagnification), shouldResizePages: false)
    }

    func previewTrackpadZoom(delta: CGFloat) {
        let currentMagnification = scrollView?.magnification ?? CGFloat(zoomMagnification)
        let nextMagnification = currentMagnification * max(0.1, 1 + delta)
        previewZoomMagnification(Double(nextMagnification))
    }

    func finishTrackpadZoom() {
        setZoomMagnification(zoomMagnification)
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

        if let paperScrollView = scrollView as? PaperScrollView {
            paperScrollView.onMagnifyGesture = { [weak self] magnificationDelta, phase in
                guard let self else { return }

                switch phase {
                case .ended, .cancelled:
                    self.finishTrackpadZoom()
                default:
                    self.previewTrackpadZoom(delta: magnificationDelta)
                }
            }
        }

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
        return ZoomViewportCalculator.fitPageMagnification(
            contentSize: scrollView.contentSize,
            minimumZoom: minimumZoom
        )
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

        return ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)
    }

    private func keepPageVisible() {
        guard let scrollView, let textView else { return }

        let clipView = scrollView.contentView
        let visibleRect = clipView.documentVisibleRect
        let pageFrame = textView.currentPageStackFrame
        let targetCenter = pageFrame.intersects(visibleRect)
            ? ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)
            : NSPoint(x: pageFrame.midX, y: pageFrame.midY)

        let targetOrigin = ZoomViewportCalculator.clampedVisibleOrigin(
            centeredAt: targetCenter,
            visibleSize: visibleRect.size,
            documentBounds: textView.bounds
        )

        guard abs(clipView.bounds.origin.x - targetOrigin.x) > 0.5
            || abs(clipView.bounds.origin.y - targetOrigin.y) > 0.5 else {
            return
        }

        clipView.scroll(to: targetOrigin)
        scrollView.reflectScrolledClipView(clipView)
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
