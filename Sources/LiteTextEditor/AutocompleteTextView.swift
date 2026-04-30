import AppKit

final class AutocompleteTextView: NSTextView {
    static let paperWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792
    static let pageMargin: CGFloat = 72
    static let pageGap: CGFloat = 34
    static let deskPadding: CGFloat = 36
    static let pageTextWidth = paperWidth - (pageMargin * 2)
    static let pageContentHeight = pageHeight - (pageMargin * 2)
    static let textLayoutDimensionLimit: CGFloat = 100_000
    static let suggestionRefreshDelay: TimeInterval = 0.12

    struct SuggestionRefreshKey: Equatable {
        let selectionLocation: Int
        let selectionLength: Int
        let stringLength: Int
        let contentGeneration: Int
        let maxSuggestionWords: Int
    }

    struct PageMeasurementKey: Equatable {
        let contentGeneration: Int
        let stringLength: Int
    }

    var maxSuggestionWords = 4
    var onDocumentMetricsChanged: (() -> Void)?
    var onAcceptSpellingCorrection: (() -> Void)?
    var onCloseSpellingCorrection: (() -> Void)?
    var onMoveSpellingCorrectionSelection: ((Int) -> Void)?
    var isSpellingCorrectionReviewActive = false
    var currentPageCount: Int { renderedPageCount }
    var currentPageStackFrame: NSRect {
        pageStackFrame(forPageCount: renderedPageCount, boundsSize: bounds.size)
    }

    let suggestionEngine: SuggestionProviding = PhraseSuggestionEngine()
    let localAIProvider = LocalAISuggestionProvider()
    let suggestionLabel = NSTextField(labelWithString: "")
    var currentSuggestion: String?
    var didRequestInitialFocus = false
    var isAcceptingSuggestionWord = false
    var pendingPaperResize = false
    var pendingSuggestionRefreshWorkItem: DispatchWorkItem?
    var contentGeneration = 0
    var lastSuggestionRefreshKey: SuggestionRefreshKey?
    var renderedPageCount = 1
    var lastPaperLayoutWidth: CGFloat = -1
    var cachedPageMeasurementKey: PageMeasurementKey?
    var cachedMeasuredPageCount = 1
    private var preservedVisibleOriginDuringChange: NSPoint?
    private var visibleOriginPreservationDepth = 0

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configureSuggestionLabel()
    }

    override var isOpaque: Bool {
        true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSuggestionLabel()
    }

    override func keyDown(with event: NSEvent) {
        if isSpellingCorrectionReviewActive {
            switch event.keyCode {
            case 36, 76:
                onAcceptSpellingCorrection?()
                return
            case 53:
                onCloseSpellingCorrection?()
                return
            case 125:
                onMoveSpellingCorrectionSelection?(1)
                return
            case 126:
                onMoveSpellingCorrectionSelection?(-1)
                return
            default:
                break
            }
        }

        if event.keyCode == 53 {
            clearSuggestion()
            return
        }

        if event.keyCode == 48, currentSuggestion != nil {
            acceptSuggestion()
            return
        }

        if event.keyCode == 124, event.modifierFlags.contains(.option), currentSuggestion != nil {
            acceptNextSuggestionWord()
            return
        }

        super.keyDown(with: event)
    }

    override func didChangeText() {
        let preservedVisibleOrigin = preservedVisibleOriginDuringChange
        super.didChangeText()
        contentGeneration &+= 1
        updatePagesAfterTextChange()
        onDocumentMetricsChanged?()
        if let preservedVisibleOrigin {
            restoreVisibleOrigin(preservedVisibleOrigin)
        } else {
            keepInsertionPointVisible()
        }
        if !isAcceptingSuggestionWord {
            scheduleSuggestionRefresh()
        }
    }

    override func setSelectedRange(_ charRange: NSRange) {
        let oldRange = selectedRange()
        super.setSelectedRange(charRange)
        guard !NSEqualRanges(oldRange, selectedRange()) else { return }
        if !isAcceptingSuggestionWord {
            scheduleSuggestionRefresh()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updatePaperLayout()
        ensurePaperHeightFitsContent()
        requestInitialFocusIfNeeded()
        refreshSuggestion()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updatePaperLayout()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        ensurePaperHeightFitsContent()
    }

    override func draw(_ dirtyRect: NSRect) {
        drawPaperBackground(in: dirtyRect)
        super.draw(dirtyRect)
    }

    func effectiveRangeForFormatting() -> NSRange {
        let selection = selectedRange()
        guard selection.length == 0 else { return selection }
        return NSRange(location: selection.location, length: 0)
    }

    func effectiveParagraphRangeForFormatting() -> NSRange {
        let selection = selectedRange()
        let nsString = string as NSString

        guard nsString.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let safeLocation = min(selection.location, nsString.length - 1)
        let baseRange = selection.length > 0 ? selection : NSRange(location: safeLocation, length: 0)
        return nsString.paragraphRange(for: baseRange)
    }

    func preservingVisibleOrigin(_ changes: () -> Void) {
        guard let scrollView = enclosingScrollView else {
            changes()
            return
        }

        let visibleOrigin = preservedVisibleOriginDuringChange
            ?? scrollView.contentView.documentVisibleRect.origin

        visibleOriginPreservationDepth += 1
        preservedVisibleOriginDuringChange = visibleOrigin
        changes()
        visibleOriginPreservationDepth -= 1

        if visibleOriginPreservationDepth == 0 {
            preservedVisibleOriginDuringChange = nil
        }

        restoreVisibleOrigin(visibleOrigin)
        DispatchQueue.main.async { [weak self] in
            self?.restoreVisibleOrigin(visibleOrigin)
        }
    }

    func refreshLayoutAfterFormattingChange() {
        preservingVisibleOrigin { [weak self] in
            guard let self else { return }
            self.updatePaperLayout()
            self.ensurePaperHeightFitsContent()
            self.needsDisplay = true
        }
    }

    @discardableResult
    func performUndoableAttributeEdit(
        in range: NSRange,
        actionName: String,
        _ edit: (NSTextStorage, NSRange) -> Bool
    ) -> Bool {
        guard let textStorage else { return false }

        let editRange = clampedRangeForTextStorage(range)
        guard editRange.length > 0 else { return false }
        guard shouldChangeText(in: editRange, replacementString: nil) else { return false }

        var didEdit = false

        preservingVisibleOrigin {
            textStorage.beginEditing()
            didEdit = edit(textStorage, editRange)
            textStorage.endEditing()

            guard didEdit else { return }
            didChangeText()
            updatePaperLayout()
            ensurePaperHeightFitsContent()
            needsDisplay = true
        }

        if didEdit {
            undoManager?.setActionName(actionName)
            breakUndoCoalescing()
        }

        return didEdit
    }

    @discardableResult
    func togglePlainList() -> Bool {
        let nsString = string as NSString
        let paragraphRange = effectiveParagraphRangeForFormatting()
        let selectedText = nsString.substring(with: paragraphRange)
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let lines = selectedText.components(separatedBy: .newlines)
        let transformed = lines.map { line in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }

            if line.hasPrefix("- ") {
                return String(line.dropFirst(2))
            }

            return "- \(line)"
        }
        .joined(separator: "\n")

        guard transformed != selectedText else { return false }
        guard shouldChangeText(in: paragraphRange, replacementString: transformed) else { return false }
        textStorage?.replaceCharacters(in: paragraphRange, with: transformed)
        didChangeText()
        undoManager?.setActionName("Bulleted List")
        breakUndoCoalescing()
        return true
    }

    @discardableResult
    func toggleNumberedList() -> Bool {
        let nsString = string as NSString
        let paragraphRange = effectiveParagraphRangeForFormatting()
        let selectedText = nsString.substring(with: paragraphRange)
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        var number = 1

        let lines = selectedText.components(separatedBy: .newlines)
        let transformed = lines.map { line in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }

            if let range = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                return String(line[range.upperBound...])
            }

            defer { number += 1 }
            return "\(number). \(line)"
        }
        .joined(separator: "\n")

        guard transformed != selectedText else { return false }
        guard shouldChangeText(in: paragraphRange, replacementString: transformed) else { return false }
        textStorage?.replaceCharacters(in: paragraphRange, with: transformed)
        didChangeText()
        undoManager?.setActionName("Numbered List")
        breakUndoCoalescing()
        return true
    }

    @discardableResult
    func increasePlainIndent() -> Bool {
        transformSelectedParagraphLines { line, _ in
            line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? line : "\t\(line)"
        }
    }

    @discardableResult
    func decreasePlainIndent() -> Bool {
        transformSelectedParagraphLines { line, _ in
            if line.hasPrefix("\t") {
                return String(line.dropFirst())
            }

            if line.hasPrefix("    ") {
                return String(line.dropFirst(4))
            }

            return line
        }
    }

    func currentParagraphLineSpacing() -> CGFloat {
        paragraphStyleForFormatting().lineSpacing
    }

    func setSelectedParagraphLineSpacing(_ spacing: CGFloat) {
        let paragraphRange = effectiveParagraphRangeForFormatting()

        let paragraphStyle = paragraphStyleForFormatting().mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = min(max(spacing, 0), 48)

        if paragraphRange.length > 0 {
            guard shouldChangeText(in: paragraphRange, replacementString: nil) else { return }
            textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            didChangeText()
            undoManager?.setActionName("Line Spacing")
            breakUndoCoalescing()
        } else {
            typingAttributes[.paragraphStyle] = paragraphStyle
        }

        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }

    func currentParagraphIndents() -> (firstLine: CGFloat, head: CGFloat) {
        let paragraphStyle = paragraphStyleForFormatting()
        return (paragraphStyle.firstLineHeadIndent, paragraphStyle.headIndent)
    }

    func setSelectedParagraphIndents(firstLine: CGFloat? = nil, head: CGFloat? = nil) {
        let paragraphRange = effectiveParagraphRangeForFormatting()

        let paragraphStyle = paragraphStyleForFormatting().mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()

        if let firstLine {
            paragraphStyle.firstLineHeadIndent = min(max(firstLine, 0), Self.pageTextWidth)
        }

        if let head {
            paragraphStyle.headIndent = min(max(head, 0), Self.pageTextWidth)
        }

        if paragraphRange.length > 0 {
            guard shouldChangeText(in: paragraphRange, replacementString: nil) else { return }
            textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            didChangeText()
            undoManager?.setActionName("Indent")
            breakUndoCoalescing()
        } else {
            typingAttributes[.paragraphStyle] = paragraphStyle
        }

        enclosingScrollView?.horizontalRulerView?.needsDisplay = true
    }

    @discardableResult
    func setSelectedParagraphAlignment(_ alignment: NSTextAlignment) -> Bool {
        let paragraphRange = effectiveParagraphRangeForFormatting()
        guard paragraphRange.length > 0 else {
            let paragraphStyle = (typingAttributes[.paragraphStyle] as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            guard !paragraphAlignment(paragraphStyle.alignment, matches: alignment) else {
                return false
            }

            paragraphStyle.alignment = alignment
            typingAttributes[.paragraphStyle] = paragraphStyle
            return false
        }

        guard shouldChangeText(in: paragraphRange, replacementString: nil),
              let textStorage else {
            return false
        }

        let nsString = string as NSString
        var didUpdate = false

        textStorage.beginEditing()
        nsString.enumerateSubstrings(
            in: paragraphRange,
            options: [.byParagraphs, .substringNotRequired]
        ) { _, _, enclosingRange, _ in
            guard enclosingRange.length > 0 else { return }

            let styleLocation = min(enclosingRange.location, max(textStorage.length - 1, 0))
            let paragraphStyle = (
                textStorage.attribute(.paragraphStyle, at: styleLocation, effectiveRange: nil) as? NSParagraphStyle
                ?? self.paragraphStyleForFormatting()
            )
            let mutableStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()

            guard !self.paragraphAlignment(mutableStyle.alignment, matches: alignment) else {
                return
            }

            mutableStyle.alignment = alignment
            textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: enclosingRange)
            didUpdate = true
        }
        textStorage.endEditing()

        guard didUpdate else { return false }
        didChangeText()
        undoManager?.setActionName("Alignment")
        breakUndoCoalescing()
        enclosingScrollView?.horizontalRulerView?.needsDisplay = true
        return true
    }

    @discardableResult
    private func transformSelectedParagraphLines(_ transform: (String, Int) -> String) -> Bool {
        let paragraphRange = effectiveParagraphRangeForFormatting()

        let nsString = string as NSString
        let selectedText = nsString.substring(with: paragraphRange)
        let transformed = selectedText
            .components(separatedBy: .newlines)
            .enumerated()
            .map { index, line in transform(line, index) }
            .joined(separator: "\n")

        guard transformed != selectedText else { return false }
        guard shouldChangeText(in: paragraphRange, replacementString: transformed) else { return false }
        textStorage?.replaceCharacters(in: paragraphRange, with: transformed)
        didChangeText()
        undoManager?.setActionName("Indent")
        breakUndoCoalescing()
        return true
    }

    private func clampedRangeForTextStorage(_ range: NSRange) -> NSRange {
        guard let textStorage else { return NSRange(location: 0, length: 0) }
        let location = min(max(range.location, 0), textStorage.length)
        let length = min(max(range.length, 0), textStorage.length - location)
        return NSRange(location: location, length: length)
    }

    private func paragraphAlignment(_ currentAlignment: NSTextAlignment, matches requestedAlignment: NSTextAlignment) -> Bool {
        currentAlignment == requestedAlignment || (currentAlignment == .natural && requestedAlignment == .left)
    }

    private func paragraphStyleForFormatting() -> NSParagraphStyle {
        if let paragraphStyle = typingAttributes[.paragraphStyle] as? NSParagraphStyle {
            return paragraphStyle
        }

        guard let textStorage, textStorage.length > 0 else {
            return defaultParagraphStyle ?? NSParagraphStyle.default
        }

        let selection = selectedRange()
        let location = min(max(selection.location, 0), textStorage.length - 1)

        return textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            ?? defaultParagraphStyle
            ?? NSParagraphStyle.default
    }


}

extension NSColor {
    static let liteTextEditorDesk = NSColor(
        calibratedRed: 0.88,
        green: 0.89,
        blue: 0.91,
        alpha: 1
    )
}
