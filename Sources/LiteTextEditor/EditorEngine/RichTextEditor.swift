import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    let controller: EditorController
    let maxSuggestionWords: Int
    let isInlineSuggestionsEnabled: Bool
    let isContinuousSpellCheckingEnabled: Bool
    let isGrammarCheckingEnabled: Bool
    let isAutomaticTextReplacementEnabled: Bool
    let isAutomaticQuoteSubstitutionEnabled: Bool
    let isAutomaticDashSubstitutionEnabled: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PaperScrollView()
        scrollView.contentView = PaperClipView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentInsets = NSEdgeInsets(
            top: ChromeStyle.regularToolbarHeight,
            left: 0,
            bottom: 0,
            right: 0
        )
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .liteTextEditorDesk
        scrollView.allowsMagnification = false
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        let contentSize = NSSize(
            width: max(scrollView.contentSize.width, AutocompleteTextView.paperWidth),
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
        textView.isContinuousSpellCheckingEnabled = isContinuousSpellCheckingEnabled
        textView.isAutomaticSpellingCorrectionEnabled = isAutomaticTextReplacementEnabled
        textView.isGrammarCheckingEnabled = isGrammarCheckingEnabled
        textView.isAutomaticQuoteSubstitutionEnabled = isAutomaticQuoteSubstitutionEnabled
        textView.isAutomaticDashSubstitutionEnabled = isAutomaticDashSubstitutionEnabled
        textView.isAutomaticTextReplacementEnabled = isAutomaticTextReplacementEnabled
        textView.maxSuggestionWords = maxSuggestionWords
        textView.isInlineSuggestionEnabled = isInlineSuggestionsEnabled
        textView.suggestionProvider = controller.suggestionProvider
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
        textView.onPredictionStateChanged = { [weak controller] state in
            controller?.updatePredictionState(state)
        }
        textView.onFormattingSampleLocationChanged = { [weak controller] in
            controller?.scheduleFormattingStateRefresh()
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
        if textView.maxSuggestionWords != maxSuggestionWords {
            textView.maxSuggestionWords = maxSuggestionWords
            if textView.isInlineSuggestionEnabled {
                textView.refreshSuggestion()
            }
        }

        if textView.isInlineSuggestionEnabled != isInlineSuggestionsEnabled {
            textView.isInlineSuggestionEnabled = isInlineSuggestionsEnabled
        }

        if textView.isContinuousSpellCheckingEnabled != isContinuousSpellCheckingEnabled {
            textView.isContinuousSpellCheckingEnabled = isContinuousSpellCheckingEnabled
        }

        if textView.isGrammarCheckingEnabled != isGrammarCheckingEnabled {
            textView.isGrammarCheckingEnabled = isGrammarCheckingEnabled
        }

        if textView.isAutomaticSpellingCorrectionEnabled != isAutomaticTextReplacementEnabled {
            textView.isAutomaticSpellingCorrectionEnabled = isAutomaticTextReplacementEnabled
        }

        if textView.isAutomaticTextReplacementEnabled != isAutomaticTextReplacementEnabled {
            textView.isAutomaticTextReplacementEnabled = isAutomaticTextReplacementEnabled
        }

        if textView.isAutomaticQuoteSubstitutionEnabled != isAutomaticQuoteSubstitutionEnabled {
            textView.isAutomaticQuoteSubstitutionEnabled = isAutomaticQuoteSubstitutionEnabled
        }

        if textView.isAutomaticDashSubstitutionEnabled != isAutomaticDashSubstitutionEnabled {
            textView.isAutomaticDashSubstitutionEnabled = isAutomaticDashSubstitutionEnabled
        }

        if controller.textView !== textView {
            controller.textView = textView
        }

        if controller.scrollView !== nsView {
            controller.scrollView = nsView
        }

        if textView.usesRuler {
            textView.usesRuler = false
        }

        if textView.isRulerVisible {
            textView.isRulerVisible = false
        }

        if nsView.hasHorizontalRuler {
            nsView.hasHorizontalRuler = false
        }

        if nsView.hasVerticalRuler {
            nsView.hasVerticalRuler = false
        }

        if nsView.rulersVisible {
            nsView.rulersVisible = false
        }

        if nsView.horizontalRulerView != nil {
            nsView.horizontalRulerView = nil
        }

        if nsView.verticalRulerView != nil {
            nsView.verticalRulerView = nil
        }
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
            center.addObserver(self, selector: #selector(newDocument), name: .liteTextEditorNewDocument, object: nil)
            center.addObserver(self, selector: #selector(openDocument), name: .liteTextEditorOpenDocument, object: nil)
            center.addObserver(self, selector: #selector(openRecentDocument), name: .liteTextEditorOpenRecentDocument, object: nil)
            center.addObserver(self, selector: #selector(saveDocument), name: .liteTextEditorSaveDocument, object: nil)
            center.addObserver(self, selector: #selector(saveDocumentAs), name: .liteTextEditorSaveDocumentAs, object: nil)
            center.addObserver(self, selector: #selector(exportPDF), name: .liteTextEditorExportPDF, object: nil)
            center.addObserver(self, selector: #selector(printDocument), name: .liteTextEditorPrintDocument, object: nil)
            center.addObserver(self, selector: #selector(performFindPanelAction), name: .liteTextEditorFindPanelAction, object: nil)
            center.addObserver(self, selector: #selector(confirmQuit), name: .liteTextEditorConfirmQuit, object: nil)
        }

        @objc private func newDocument() {
            controller?.newDocument()
        }

        @objc private func openDocument() {
            controller?.openDocument()
        }

        @objc private func openRecentDocument(_ notification: Notification) {
            guard let url = notification.object as? URL else { return }
            controller?.openRecentDocument(url)
        }

        @objc private func saveDocument() {
            controller?.saveDocumentInBackground()
        }

        @objc private func saveDocumentAs() {
            controller?.saveDocumentAsInBackground()
        }

        @objc private func exportPDF() {
            controller?.exportPDF()
        }

        @objc private func printDocument() {
            guard let textView = controller?.textView else { return }
            textView.window?.makeFirstResponder(textView)
            NSApp.sendAction(NSSelectorFromString("print:"), to: textView, from: nil)
        }

        @objc private func performFindPanelAction(_ notification: Notification) {
            guard let actionRawValue = notification.object as? Int,
                  let textView = controller?.textView else { return }

            textView.window?.makeFirstResponder(textView)

            let sender = NSMenuItem()
            sender.tag = actionRawValue
            textView.performFindPanelAction(sender)
        }

        @objc private func confirmQuit(_ notification: Notification) {
            guard let response = notification.object as? QuitConfirmationResponse else { return }
            response.reply = controller?.confirmQuit() ?? .terminateNow
        }

        func registerFormattingCommands() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(toggleBold), name: .liteTextEditorToggleBold, object: nil)
            center.addObserver(self, selector: #selector(toggleItalic), name: .liteTextEditorToggleItalic, object: nil)
            center.addObserver(self, selector: #selector(toggleUnderline), name: .liteTextEditorToggleUnderline, object: nil)
            center.addObserver(self, selector: #selector(toggleStrikethrough), name: .liteTextEditorToggleStrikethrough, object: nil)
            center.addObserver(self, selector: #selector(setBaseline), name: .liteTextEditorSetBaseline, object: nil)
            center.addObserver(self, selector: #selector(toggleHighlight), name: .liteTextEditorToggleHighlight, object: nil)
            center.addObserver(self, selector: #selector(setHighlightColor), name: .liteTextEditorSetHighlightColor, object: nil)
            center.addObserver(self, selector: #selector(clearTextColor), name: .liteTextEditorClearTextColor, object: nil)
            center.addObserver(self, selector: #selector(copyFormatting), name: .liteTextEditorCopyFormatting, object: nil)
            center.addObserver(self, selector: #selector(pasteFormatting), name: .liteTextEditorPasteFormatting, object: nil)
            center.addObserver(self, selector: #selector(applyTextCasing), name: .liteTextEditorApplyTextCasing, object: nil)
            center.addObserver(self, selector: #selector(setCharacterSpacing), name: .liteTextEditorSetCharacterSpacing, object: nil)
            center.addObserver(self, selector: #selector(clearFormatting), name: .liteTextEditorClearFormatting, object: nil)
            center.addObserver(self, selector: #selector(setTextPreset), name: .liteTextEditorSetTextPreset, object: nil)
            center.addObserver(self, selector: #selector(toggleBulletedList), name: .liteTextEditorToggleBulletedList, object: nil)
            center.addObserver(self, selector: #selector(toggleNumberedList), name: .liteTextEditorToggleNumberedList, object: nil)
            center.addObserver(self, selector: #selector(toggleChecklist), name: .liteTextEditorToggleChecklist, object: nil)
            center.addObserver(self, selector: #selector(setListStyle), name: .liteTextEditorSetListStyle, object: nil)
            center.addObserver(self, selector: #selector(applyListNumberingAction), name: .liteTextEditorApplyListNumberingAction, object: nil)
            center.addObserver(self, selector: #selector(increaseIndent), name: .liteTextEditorIncreaseIndent, object: nil)
            center.addObserver(self, selector: #selector(decreaseIndent), name: .liteTextEditorDecreaseIndent, object: nil)
            center.addObserver(self, selector: #selector(alignLeft), name: .liteTextEditorAlignLeft, object: nil)
            center.addObserver(self, selector: #selector(alignCenter), name: .liteTextEditorAlignCenter, object: nil)
            center.addObserver(self, selector: #selector(alignRight), name: .liteTextEditorAlignRight, object: nil)
            center.addObserver(self, selector: #selector(justifyText), name: .liteTextEditorJustifyText, object: nil)
            center.addObserver(self, selector: #selector(setLineSpacing), name: .liteTextEditorSetLineSpacing, object: nil)
            center.addObserver(self, selector: #selector(applyParagraphSpacing), name: .liteTextEditorApplyParagraphSpacing, object: nil)
            center.addObserver(self, selector: #selector(applyParagraphIndent), name: .liteTextEditorApplyParagraphIndent, object: nil)
            center.addObserver(self, selector: #selector(toggleKeepParagraphTogether), name: .liteTextEditorToggleKeepParagraphTogether, object: nil)
            center.addObserver(self, selector: #selector(toggleKeepWithNext), name: .liteTextEditorToggleKeepWithNext, object: nil)
            center.addObserver(self, selector: #selector(beginSpellingReview), name: .liteTextEditorBeginSpellingReview, object: nil)
        }

        func registerZoomCommands() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(zoomIn), name: .liteTextEditorZoomIn, object: nil)
            center.addObserver(self, selector: #selector(zoomOut), name: .liteTextEditorZoomOut, object: nil)
            center.addObserver(self, selector: #selector(fitPageToScreen), name: .liteTextEditorZoomFitPage, object: nil)
            center.addObserver(self, selector: #selector(actualSize), name: .liteTextEditorZoomActualSize, object: nil)
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

        @objc private func toggleStrikethrough() {
            controller?.toggleStrikethrough()
        }

        @objc private func setBaseline(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = TextBaselineOption(rawValue: rawValue) else { return }
            controller?.setBaseline(option)
        }

        @objc private func toggleHighlight() {
            controller?.toggleHighlight()
        }

        @objc private func setHighlightColor(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = HighlightColorOption(rawValue: rawValue) else { return }
            controller?.applyHighlight(option)
        }

        @objc private func clearTextColor() {
            controller?.clearTextColor()
        }

        @objc private func copyFormatting() {
            controller?.copyFormatting()
        }

        @objc private func pasteFormatting() {
            controller?.pasteFormatting()
        }

        @objc private func applyTextCasing(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = TextCasingOption(rawValue: rawValue) else { return }
            controller?.applyTextCasing(option)
        }

        @objc private func setCharacterSpacing(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = CharacterSpacingOption(rawValue: rawValue) else { return }
            controller?.setCharacterSpacing(option)
        }

        @objc private func clearFormatting() {
            controller?.clearFormatting()
        }

        @objc private func setTextPreset(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let preset = TextPreset(rawValue: rawValue) else { return }

            controller?.applyPresetUsingCurrentFont(preset)
        }

        @objc private func toggleBulletedList() {
            controller?.togglePlainList()
        }

        @objc private func toggleNumberedList() {
            controller?.toggleNumberedList()
        }

        @objc private func toggleChecklist() {
            controller?.toggleChecklist()
        }

        @objc private func setListStyle(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = ListStyleOption(rawValue: rawValue) else { return }
            controller?.applyListStyle(option)
        }

        @objc private func applyListNumberingAction(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let action = ListNumberingAction(rawValue: rawValue) else { return }
            controller?.applyListNumberingAction(action)
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

        @objc private func setLineSpacing(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = LineSpacingOption(rawValue: rawValue) else { return }
            controller?.setLineSpacing(option)
        }

        @objc private func applyParagraphSpacing(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = ParagraphSpacingOption(rawValue: rawValue) else { return }
            controller?.applyParagraphSpacing(option)
        }

        @objc private func applyParagraphIndent(_ notification: Notification) {
            guard let rawValue = notification.object as? String,
                  let option = ParagraphIndentOption(rawValue: rawValue) else { return }
            controller?.applyParagraphIndent(option)
        }

        @objc private func toggleKeepParagraphTogether() {
            controller?.toggleKeepParagraphTogether()
        }

        @objc private func toggleKeepWithNext() {
            controller?.toggleKeepWithNext()
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

        func textDidChange(_ notification: Notification) {
            controller?.scheduleFormattingStateRefresh()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller?.scheduleFormattingStateRefresh()
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
            let usedHeight = max(
                lineFragmentRect.pointee.height,
                lineFragmentUsedRect.pointee.maxY - lineFragmentRect.pointee.origin.y
            )
            let visualY = AutocompleteTextView.visualLineOriginY(forContentY: contentY, usedHeight: usedHeight)
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
