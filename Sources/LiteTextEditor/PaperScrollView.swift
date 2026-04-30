import AppKit

final class PaperScrollView: NSScrollView {
    var didLayout: (() -> Void)?
    var onMagnifyGesture: ((CGFloat, NSEvent.Phase) -> Void)?
    private var pendingDocumentResize = false
    private var resizeGeneration = 0
    private var hasPreparedFirstScroll = false

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

    override func scrollWheel(with event: NSEvent) {
        prepareDocumentForFirstScrollIfNeeded()
        super.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        if let onMagnifyGesture {
            onMagnifyGesture(event.magnification, event.phase)
        } else {
            super.magnify(with: event)
        }
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
}
