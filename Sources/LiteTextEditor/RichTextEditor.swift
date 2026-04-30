import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    let controller: EditorController
    let maxSuggestionWords: Int

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PaperScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .liteTextEditorDesk
        scrollView.allowsMagnification = true
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        let contentSize = NSSize(
            width: max(scrollView.contentSize.width, AutocompleteTextView.paperWidth + (AutocompleteTextView.deskPadding * 2)),
            height: max(
                scrollView.contentSize.height,
                AutocompleteTextView.pageHeight + (AutocompleteTextView.deskPadding * 2)
            )
        )
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: AutocompleteTextView.pageTextWidth,
                height: AutocompleteTextView.textLayoutDimensionLimit
            )
        )

        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0

        layoutManager.addTextContainer(textContainer)
        layoutManager.delegate = context.coordinator
        textStorage.addLayoutManager(layoutManager)

        let textView = AutocompleteTextView(
            frame: NSRect(origin: .zero, size: contentSize),
            textContainer: textContainer
        )
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: AutocompleteTextView.textLayoutDimensionLimit,
            height: AutocompleteTextView.textLayoutDimensionLimit
        )
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: AutocompleteTextView.pageMargin, height: AutocompleteTextView.pageMargin)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.undoManager?.levelsOfUndo = 200
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = true
        textView.usesFindPanel = true
        textView.usesRuler = false
        textView.isRulerVisible = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.maxSuggestionWords = maxSuggestionWords
        textView.delegate = context.coordinator
        textView.onDocumentMetricsChanged = { [weak controller] in
            controller?.markDocumentEdited()
            controller?.scheduleDocumentStatisticsRefresh()
        }
        textView.onAcceptSpellingCorrection = { [weak controller] in
            controller?.applyCurrentSpellingCorrection()
        }
        textView.onCloseSpellingCorrection = { [weak controller] in
            controller?.closeSpellingReview()
        }
        textView.onMoveSpellingCorrectionSelection = { [weak controller] delta in
            controller?.moveSpellingSuggestionSelection(by: delta)
        }
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]

        scrollView.documentView = textView
        scrollView.didLayout = { [weak controller] in
            controller?.refreshZoomForLayout()
        }
        controller.textView = textView
        controller.scrollView = scrollView
        controller.restoreLastSessionIfNeeded()
        controller.refreshDocumentStatistics()
        controller.refreshFormattingState()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.acceptSuggestion),
            name: .liteTextEditorAcceptSuggestion,
            object: nil
        )
        context.coordinator.registerDocumentCommands()
        context.coordinator.registerFormattingCommands()
        context.coordinator.registerZoomCommands()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? AutocompleteTextView else { return }
        textView.maxSuggestionWords = maxSuggestionWords
        textView.onDocumentMetricsChanged = { [weak controller] in
            controller?.markDocumentEdited()
            controller?.scheduleDocumentStatisticsRefresh()
        }
        textView.onAcceptSpellingCorrection = { [weak controller] in
            controller?.applyCurrentSpellingCorrection()
        }
        textView.onCloseSpellingCorrection = { [weak controller] in
            controller?.closeSpellingReview()
        }
        textView.onMoveSpellingCorrectionSelection = { [weak controller] delta in
            controller?.moveSpellingSuggestionSelection(by: delta)
        }
        if controller.textView !== textView {
            controller.textView = textView
        }

        if controller.scrollView !== nsView {
            controller.scrollView = nsView
        }

        controller.refreshFormattingState()
        textView.usesRuler = false
        textView.isRulerVisible = false
        nsView.hasHorizontalRuler = false
        nsView.hasVerticalRuler = false
        nsView.rulersVisible = false
        nsView.horizontalRulerView = nil
        nsView.verticalRulerView = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        private weak var controller: EditorController?

        init(controller: EditorController) {
            self.controller = controller
        }

        @objc func acceptSuggestion() {
            controller?.textView?.acceptSuggestion()
        }

        func registerDocumentCommands() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(openDocument), name: .liteTextEditorOpenDocument, object: nil)
            center.addObserver(self, selector: #selector(saveDocument), name: .liteTextEditorSaveDocument, object: nil)
            center.addObserver(self, selector: #selector(saveDocumentAs), name: .liteTextEditorSaveDocumentAs, object: nil)
            center.addObserver(self, selector: #selector(exportPDF), name: .liteTextEditorExportPDF, object: nil)
            center.addObserver(self, selector: #selector(confirmQuit), name: .liteTextEditorConfirmQuit, object: nil)
            center.addObserver(self, selector: #selector(flushAutosave), name: .liteTextEditorFlushAutosave, object: nil)
        }

        @objc private func openDocument() {
            controller?.openDocument()
        }

        @objc private func saveDocument() {
            controller?.saveDocument()
        }

        @objc private func saveDocumentAs() {
            controller?.saveDocumentAs()
        }

        @objc private func exportPDF() {
            controller?.exportPDF()
        }

        @objc private func confirmQuit(_ notification: Notification) {
            guard let response = notification.object as? QuitConfirmationResponse else { return }
            response.reply = controller?.confirmQuit() ?? .terminateNow
        }

        @objc private func flushAutosave() {
            controller?.flushAutosave()
        }

        func registerFormattingCommands() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(toggleBold), name: .liteTextEditorToggleBold, object: nil)
            center.addObserver(self, selector: #selector(toggleItalic), name: .liteTextEditorToggleItalic, object: nil)
            center.addObserver(self, selector: #selector(toggleUnderline), name: .liteTextEditorToggleUnderline, object: nil)
            center.addObserver(self, selector: #selector(toggleBulletedList), name: .liteTextEditorToggleBulletedList, object: nil)
            center.addObserver(self, selector: #selector(toggleNumberedList), name: .liteTextEditorToggleNumberedList, object: nil)
            center.addObserver(self, selector: #selector(increaseIndent), name: .liteTextEditorIncreaseIndent, object: nil)
            center.addObserver(self, selector: #selector(decreaseIndent), name: .liteTextEditorDecreaseIndent, object: nil)
            center.addObserver(self, selector: #selector(alignLeft), name: .liteTextEditorAlignLeft, object: nil)
            center.addObserver(self, selector: #selector(alignCenter), name: .liteTextEditorAlignCenter, object: nil)
            center.addObserver(self, selector: #selector(alignRight), name: .liteTextEditorAlignRight, object: nil)
            center.addObserver(self, selector: #selector(justifyText), name: .liteTextEditorJustifyText, object: nil)
            center.addObserver(self, selector: #selector(beginSpellingReview), name: .liteTextEditorBeginSpellingReview, object: nil)
        }

        func registerZoomCommands() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(zoomIn), name: .liteTextEditorZoomIn, object: nil)
            center.addObserver(self, selector: #selector(zoomOut), name: .liteTextEditorZoomOut, object: nil)
            center.addObserver(self, selector: #selector(fitPageToScreen), name: .liteTextEditorZoomFitPage, object: nil)
            center.addObserver(self, selector: #selector(actualSize), name: .liteTextEditorZoomActualSize, object: nil)
            center.addObserver(self, selector: #selector(setZoomPreset), name: .liteTextEditorSetZoomPreset, object: nil)
        }

        @objc private func toggleBold() {
            controller?.toggleBold()
        }

        @objc private func toggleItalic() {
            controller?.toggleItalic()
        }

        @objc private func toggleUnderline() {
            controller?.toggleUnderline()
        }

        @objc private func toggleBulletedList() {
            controller?.togglePlainList()
        }

        @objc private func toggleNumberedList() {
            controller?.toggleNumberedList()
        }

        @objc private func increaseIndent() {
            controller?.increaseIndent()
        }

        @objc private func decreaseIndent() {
            controller?.decreaseIndent()
        }

        @objc private func alignLeft() {
            controller?.setAlignment(.left)
        }

        @objc private func alignCenter() {
            controller?.setAlignment(.center)
        }

        @objc private func alignRight() {
            controller?.setAlignment(.right)
        }

        @objc private func justifyText() {
            controller?.setAlignment(.justified)
        }

        @objc private func beginSpellingReview() {
            controller?.beginSpellingReview()
        }

        @objc private func zoomIn() {
            controller?.zoomIn()
        }

        @objc private func zoomOut() {
            controller?.zoomOut()
        }

        @objc private func fitPageToScreen() {
            controller?.fitPageToScreen()
        }

        @objc private func actualSize() {
            controller?.actualSize()
        }

        @objc private func setZoomPreset(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let preset = DocumentZoomPreset(rawValue: rawValue) else { return }

            controller?.setZoomPreset(preset)
        }

        func textDidChange(_ notification: Notification) {
            controller?.refreshFormattingState()
            controller?.scrollView?.horizontalRulerView?.needsDisplay = true
            controller?.scrollView?.verticalRulerView?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller?.refreshFormattingState()
            controller?.scrollView?.horizontalRulerView?.needsDisplay = true
            controller?.scrollView?.verticalRulerView?.needsDisplay = true
        }

        func layoutManager(
            _ layoutManager: NSLayoutManager,
            shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
            lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
            baselineOffset: UnsafeMutablePointer<CGFloat>,
            in textContainer: NSTextContainer,
            forGlyphRange glyphRange: NSRange
        ) -> Bool {
            let contentY = AutocompleteTextView.contentY(fromPotentialVisualY: lineFragmentRect.pointee.origin.y)
            let visualY = AutocompleteTextView.visualContentY(forContentY: contentY)
            let deltaY = visualY - lineFragmentRect.pointee.origin.y

            guard abs(deltaY) > 0.5 else {
                return true
            }

            lineFragmentRect.pointee.origin.y += deltaY
            lineFragmentUsedRect.pointee.origin.y += deltaY
            return true
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
