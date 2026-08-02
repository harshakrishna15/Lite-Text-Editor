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
        let clampedMagnification = clampedZoom(CGFloat(magnification))
        selectedZoomPreset = matchingPreset(for: clampedMagnification) ?? .custom
        setNativeMagnification(clampedMagnification)
    }

    func setZoomPreset(_ preset: DocumentZoomPreset) {
        selectedZoomPreset = preset
        let magnification: CGFloat
        switch preset {
        case .fitPage:
            magnification = fitPageMagnification()
        case .custom:
            magnification = scrollView?.magnification ?? CGFloat(zoomMagnification)
        default:
            magnification = preset.magnification ?? 1
        }
        setNativeMagnification(magnification)
    }

    func refreshZoomForLayout() {
        guard let scrollView else { return }

        if selectedZoomPreset == .fitPage {
            setNativeMagnification(fitPageMagnification())
        } else {
            synchronizeNativeMagnification(scrollView.magnification)
        }
    }

    func configureZoomForCurrentScrollView() {
        guard let scrollView else { return }

        scrollView.allowsMagnification = true
        scrollView.minMagnification = minimumZoom
        scrollView.maxMagnification = maximumZoom
        textView?.resizeForCachedPages()

        zoomMagnificationObservation = scrollView.observe(
            \.magnification,
            options: [.new]
        ) { [weak self] observedScrollView, _ in
            self?.synchronizeNativeMagnification(observedScrollView.magnification)
        }
        scrollView.contentView.postsBoundsChangedNotifications = true
        zoomClipBoundsObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.centerPageHorizontallyIfItFits()
        }

        setZoomPreset(selectedZoomPreset)
    }

    func synchronizeNativeMagnification(_ magnification: CGFloat) {
        guard magnification.isFinite else { return }
        let clampedMagnification = clampedZoom(magnification)
        let stillMatchesFitPage = selectedZoomPreset == .fitPage
            && abs(clampedMagnification - clampedZoom(fitPageMagnification())) < 0.0005

        if !stillMatchesFitPage {
            selectedZoomPreset = matchingPreset(for: clampedMagnification) ?? .custom
        }

        updateZoomDisplay(for: clampedMagnification)
    }

    private func stepZoom(direction: Int) {
        let currentMagnification = scrollView?.magnification ?? CGFloat(zoomMagnification)
        let nextPreset: DocumentZoomPreset?

        if direction > 0 {
            nextPreset = DocumentZoomPreset.fixedPresets.first {
                ($0.magnification ?? 1) > currentMagnification + 0.01
            }
        } else {
            nextPreset = DocumentZoomPreset.fixedPresets.reversed().first {
                ($0.magnification ?? 1) < currentMagnification - 0.01
            }
        }

        if let nextPreset {
            setZoomPreset(nextPreset)
        }
    }

    private func setNativeMagnification(_ magnification: CGFloat) {
        let clampedMagnification = clampedZoom(magnification)
        updateZoomDisplay(for: clampedMagnification)

        guard let scrollView else { return }
        guard abs(scrollView.magnification - clampedMagnification) > 0.001 else { return }

        scrollView.setMagnification(
            clampedMagnification,
            centeredAt: nativeZoomAnchor()
        )
    }

    private func nativeZoomAnchor() -> NSPoint {
        guard let scrollView, let textView else { return .zero }

        let visibleRect = scrollView.contentView.documentVisibleRect
        let pageFrame = textView.currentPageStackFrame

        if pageFrame.intersects(visibleRect) {
            return ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)
        }

        return NSPoint(x: pageFrame.midX, y: pageFrame.midY)
    }

    private func fitPageMagnification() -> CGFloat {
        guard let scrollView else { return 1 }
        return ZoomViewportCalculator.fitPageMagnification(
            contentSize: scrollView.contentSize,
            minimumZoom: minimumZoom
        )
    }

    private func clampedZoom(_ magnification: CGFloat) -> CGFloat {
        min(max(magnification, minimumZoom), maximumZoom)
    }

    private func updateZoomDisplay(for magnification: CGFloat) {
        let displayText = "\(Int((magnification * 100).rounded()))%"
        if zoomDisplayText != displayText {
            zoomDisplayText = displayText
        }

        let value = Double(magnification)
        if abs(zoomMagnification - value) > 0.001 {
            zoomMagnification = value
        }
    }

    private func centerPageHorizontallyIfItFits() {
        guard let scrollView, let textView else { return }
        guard scrollView.contentView.documentVisibleRect.width + PaperScrollView.horizontalWheelTolerance
            >= AutocompleteTextView.paperWidth else {
            return
        }

        textView.centerPageHorizontallyPreservingVerticalPosition()
    }

    private func matchingPreset(for magnification: CGFloat) -> DocumentZoomPreset? {
        DocumentZoomPreset.fixedPresets.first { preset in
            guard let presetMagnification = preset.magnification else { return false }
            return abs(presetMagnification - magnification) < 0.005
        }
    }
}
