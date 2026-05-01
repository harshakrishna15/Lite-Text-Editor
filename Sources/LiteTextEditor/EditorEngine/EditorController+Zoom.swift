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

    func applyTrackpadZoom(delta: CGFloat, phase: NSEvent.Phase) {
        guard !phase.contains(.ended), !phase.contains(.cancelled) else { return }
        guard abs(delta) > 0.0001 else { return }

        let boundedDelta = min(max(delta, -0.2), 0.2)
        let nextMagnification = zoomMagnification * Double(1 + boundedDelta)
        setZoomMagnification(nextMagnification)
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
        } else {
            updateZoomDisplayText(for: CGFloat(zoomMagnification))
            centerPageForCurrentLayout()
        }
    }

    func configureZoomForCurrentScrollView() {
        guard let scrollView else { return }

        scrollView.allowsMagnification = false
        scrollView.minMagnification = minimumZoom
        scrollView.maxMagnification = maximumZoom
        scrollView.magnification = 1
        (scrollView as? PaperScrollView)?.onMagnifyGesture = { [weak self] delta, phase in
            self?.applyTrackpadZoom(delta: delta, phase: phase)
        }

        setZoomPreset(selectedZoomPreset)
    }

    private func stepZoom(direction: Int) {
        let current = CGFloat(zoomMagnification)

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

        if abs(scrollView.magnification - 1) > 0.001 {
            scrollView.magnification = 1
        }

        textView.resizeForCachedPages(at: clampedMagnification)
        keepPageCentered()
        textView.refreshLayoutAfterZoomChange()
    }

    private func keepPageCentered() {
        centerPageForCurrentLayout()
    }

    private func centerPageForCurrentLayout() {
        guard let textView else { return }

        textView.centerPageHorizontallyPreservingVerticalPosition()

        DispatchQueue.main.async { [weak self] in
            self?.textView?.centerPageHorizontallyPreservingVerticalPosition()
        }
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
