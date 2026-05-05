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
    static let minimumStableCanvasMagnification: CGFloat = 0.5
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

    private struct ParsedListLine {
        let style: ListStyleOption
        let indentation: String
        let body: String
        let itemNumber: Int?
    }

    var maxSuggestionWords = 4
    var onDocumentMetricsChanged: (() -> Void)?
    var onAcceptSpellingCorrection: (() -> Void)?
    var onCloseSpellingCorrection: (() -> Void)?
    var onMoveSpellingCorrectionSelection: ((Int) -> Void)?
    var onFormattingSampleLocationChanged: (() -> Void)?
    var isSpellingCorrectionReviewActive = false
    var formattingSampleLocation: Int?
    var currentPageCount: Int { renderedPageCount }
    var currentPageStackFrame: NSRect {
        pageStackFrame(forPageCount: renderedPageCount, boundsSize: bounds.size)
    }

    var suggestionProvider: SuggestionProviding = SuggestionPipeline(
        providers: [
            PhraseSuggestionEngine()
        ]
    )
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
    var documentLayoutScale: CGFloat = 1
    private(set) var zoomLayoutRefreshCount = 0
    private var preservedVisibleOriginDuringChange: NSPoint?
    private var visibleOriginPreservationDepth = 0
    private var formattingTrackingArea: NSTrackingArea?

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

    override func insertNewline(_ sender: Any?) {
        guard continueListIfNeeded() else {
            super.insertNewline(sender)
            return
        }
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
        updateFormattingSampleLocation(nil)
        if !isAcceptingSuggestionWord {
            scheduleSuggestionRefresh()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let formattingTrackingArea {
            removeTrackingArea(formattingTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        formattingTrackingArea = trackingArea
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateFormattingSampleLocation(characterIndexForFormattingSample(from: event))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateFormattingSampleLocation(nil)
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

    func updateFormattingSampleLocation(_ location: Int?) {
        let textLength = (string as NSString).length
        let clampedLocation = location.map { min(max($0, 0), max(textLength - 1, 0)) }

        guard formattingSampleLocation != clampedLocation else { return }
        formattingSampleLocation = clampedLocation
        onFormattingSampleLocationChanged?()
    }

    private func characterIndexForFormattingSample(from event: NSEvent) -> Int? {
        guard let layoutManager, let textContainer else { return nil }

        let textLength = (string as NSString).length
        guard textLength > 0 else { return nil }

        let point = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )

        guard containerPoint.x >= 0,
              containerPoint.y >= 0,
              containerPoint.x <= textContainer.containerSize.width,
              containerPoint.y <= textContainer.containerSize.height else {
            return nil
        }

        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        guard characterIndex < textLength else { return textLength - 1 }
        return characterIndex
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

    func refreshLayoutAfterZoomChange() {
        zoomLayoutRefreshCount += 1

        if let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }

        needsDisplay = true
        updateInsertionPointStateAndRestartTimer(true)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.needsDisplay = true
            self.updateInsertionPointStateAndRestartTimer(true)
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
        toggleListStyle(.bullet)
    }

    @discardableResult
    func toggleNumberedList() -> Bool {
        toggleListStyle(.numbered)
    }

    @discardableResult
    func toggleListStyle(_ style: ListStyleOption) -> Bool {
        let nsString = string as NSString
        let paragraphRange = effectiveParagraphRangeForFormatting()
        let selectedText = nsString.substring(with: paragraphRange)

        if selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let marker = prefix(for: style, itemNumber: 1)
            let transformed = "\(marker)\(trailingNewline(in: selectedText))"
            let selectedLocation = paragraphRange.location + (marker as NSString).length
            return replaceSelectedParagraphs(
                with: transformed,
                original: selectedText,
                range: paragraphRange,
                actionName: style.title,
                selectedLocation: selectedLocation
            )
        }

        let lines = selectedText.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let shouldRemove = !nonEmptyLines.isEmpty && nonEmptyLines.allSatisfy { line in
            listStyle(for: line) == style
        }
        var itemNumber = 1

        let transformed = lines.map { line in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }

            let body = removingListPrefix(from: line)
            guard !shouldRemove else { return body }

            defer { itemNumber += 1 }
            return "\(prefix(for: style, itemNumber: itemNumber))\(body)"
        }
        .joined(separator: "\n")

        return replaceSelectedParagraphs(with: transformed, original: selectedText, range: paragraphRange, actionName: style.title)
    }

    @discardableResult
    func restartNumberedList() -> Bool {
        renumberSelectedList(startingAt: 1)
    }

    @discardableResult
    func continueNumberedList() -> Bool {
        let nsString = string as NSString
        let paragraphRange = effectiveParagraphRangeForFormatting()
        let beforeRange = NSRange(location: 0, length: paragraphRange.location)
        var startNumber = 1

        nsString.enumerateSubstrings(in: beforeRange, options: [.byLines]) { substring, _, _, _ in
            guard let substring,
                  let number = self.leadingListNumber(in: substring) else { return }
            startNumber = number + 1
        }

        return renumberSelectedList(startingAt: startNumber)
    }

    @discardableResult
    private func renumberSelectedList(startingAt startNumber: Int) -> Bool {
        let nsString = string as NSString
        let paragraphRange = effectiveParagraphRangeForFormatting()
        let selectedText = nsString.substring(with: paragraphRange)
        var itemNumber = startNumber

        let transformed = selectedText.components(separatedBy: .newlines).map { line in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return line
            }

            let body = removingListPrefix(from: line)
            defer { itemNumber += 1 }
            return "\(itemNumber). \(body)"
        }
        .joined(separator: "\n")

        return replaceSelectedParagraphs(with: transformed, original: selectedText, range: paragraphRange, actionName: "Numbering")
    }

    private func replaceSelectedParagraphs(
        with transformed: String,
        original selectedText: String,
        range paragraphRange: NSRange,
        actionName: String,
        selectedLocation: Int? = nil
    ) -> Bool {
        guard transformed != selectedText else { return false }
        guard shouldChangeText(in: paragraphRange, replacementString: transformed) else { return false }
        textStorage?.replaceCharacters(in: paragraphRange, with: transformed)
        if let selectedLocation {
            setSelectedRange(NSRange(location: selectedLocation, length: 0))
        }
        didChangeText()
        undoManager?.setActionName(actionName)
        breakUndoCoalescing()
        return true
    }

    private func trailingNewline(in text: String) -> String {
        if text.hasSuffix("\r\n") {
            return "\r\n"
        }
        if text.hasSuffix("\n") {
            return "\n"
        }
        if text.hasSuffix("\r") {
            return "\r"
        }
        return ""
    }

    private func listStyle(for line: String) -> ListStyleOption? {
        parsedListLine(from: line)?.style
    }

    private func removingListPrefix(from line: String) -> String {
        let pattern = #"^\s*(?:[-•☐]|\d+\.|[IVXLCDM]+\.|[A-Z]\.)\s+"#
        guard let range = line.range(of: pattern, options: .regularExpression) else { return line }
        return String(line[range.upperBound...])
    }

    private func continueListIfNeeded() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let nsString = string as NSString
        guard nsString.length > 0 else { return false }

        let currentLineRange = nsString.paragraphRange(for: NSRange(location: min(selection.location, nsString.length - 1), length: 0))
        let currentLine = nsString.substring(with: currentLineRange)
        guard let listLine = parsedListLine(from: currentLine) else { return false }

        let lineEnd = currentLineRange.location + currentLineRange.length
        let newlineLength = trailingNewline(in: currentLine).utf16.count
        let contentEnd = lineEnd - newlineLength
        guard selection.location >= currentLineRange.location,
              selection.location <= contentEnd else { return false }

        if listLine.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return exitListLine(
                lineRange: currentLineRange,
                contentEnd: contentEnd,
                newlineLength: newlineLength,
                indentation: listLine.indentation
            )
        }

        let nextItemNumber = nextListItemNumber(after: listLine)
        let nextPrefix = "\(listLine.indentation)\(prefix(for: listLine.style, itemNumber: nextItemNumber))"
        let insertion = "\n\(nextPrefix)"
        guard shouldChangeText(in: selection, replacementString: insertion) else { return false }

        textStorage?.replaceCharacters(in: selection, with: insertion)
        setSelectedRange(NSRange(location: selection.location + (insertion as NSString).length, length: 0))
        didChangeText()
        undoManager?.setActionName("Continue List")
        breakUndoCoalescing()
        return true
    }

    private func exitListLine(
        lineRange: NSRange,
        contentEnd: Int,
        newlineLength: Int,
        indentation: String
    ) -> Bool {
        let markerRange = NSRange(location: lineRange.location, length: contentEnd - lineRange.location)
        let replacement = newlineLength > 0 ? indentation : ""
        guard shouldChangeText(in: markerRange, replacementString: replacement) else { return false }

        textStorage?.replaceCharacters(in: markerRange, with: replacement)
        setSelectedRange(NSRange(location: lineRange.location + (replacement as NSString).length, length: 0))
        didChangeText()
        undoManager?.setActionName("End List")
        breakUndoCoalescing()
        return true
    }

    private func nextListItemNumber(after listLine: ParsedListLine) -> Int {
        switch listLine.style {
        case .numbered, .lettered, .roman:
            return (listLine.itemNumber ?? 1) + 1
        case .bullet, .dash, .checklist:
            return 1
        }
    }

    private func parsedListLine(from line: String) -> ParsedListLine? {
        let lineWithoutNewline = line.trimmingCharacters(in: .newlines)
        let pattern = #"^(\s*)(☐|-|•|\d+\.|[IVXLCDM]+\.|[A-Z]\.)\s(.*)$"#
        guard let range = lineWithoutNewline.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let matched = String(lineWithoutNewline[range])
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsMatched = matched as NSString
        guard let match = regex?.firstMatch(in: matched, range: NSRange(location: 0, length: nsMatched.length)),
              match.numberOfRanges == 4 else { return nil }

        let indentation = nsMatched.substring(with: match.range(at: 1))
        let marker = nsMatched.substring(with: match.range(at: 2))
        let body = nsMatched.substring(with: match.range(at: 3))

        if marker == "☐" {
            return ParsedListLine(style: .checklist, indentation: indentation, body: body, itemNumber: nil)
        }
        if marker == "-" {
            return ParsedListLine(style: .dash, indentation: indentation, body: body, itemNumber: nil)
        }
        if marker == "•" {
            return ParsedListLine(style: .bullet, indentation: indentation, body: body, itemNumber: nil)
        }
        if marker.range(of: #"^\d+\.$"#, options: .regularExpression) != nil {
            return ParsedListLine(
                style: .numbered,
                indentation: indentation,
                body: body,
                itemNumber: Int(marker.dropLast())
            )
        }
        if marker.range(of: #"^[IVXLCDM]+\.$"#, options: .regularExpression) != nil {
            return ParsedListLine(
                style: .roman,
                indentation: indentation,
                body: body,
                itemNumber: integerValue(forRomanListMarker: String(marker.dropLast()))
            )
        }
        return ParsedListLine(
            style: .lettered,
            indentation: indentation,
            body: body,
            itemNumber: integerValue(forLetterListMarker: String(marker.dropLast()))
        )
    }

    private func prefix(for style: ListStyleOption, itemNumber: Int) -> String {
        switch style {
        case .bullet:
            return "• "
        case .dash:
            return "- "
        case .numbered:
            return "\(itemNumber). "
        case .lettered:
            return "\(letterListMarker(for: itemNumber)). "
        case .roman:
            return "\(romanListMarker(for: itemNumber)). "
        case .checklist:
            return "☐ "
        }
    }

    private func leadingListNumber(in line: String) -> Int? {
        guard let range = line.range(of: #"^\s*(\d+)\. "#, options: .regularExpression) else {
            return nil
        }
        let marker = line[range].trimmingCharacters(in: .whitespaces)
        return Int(marker.dropLast())
    }

    private func letterListMarker(for number: Int) -> String {
        let clamped = max(1, number)
        let scalarValue = Int(("A" as UnicodeScalar).value) + ((clamped - 1) % 26)
        return String(UnicodeScalar(scalarValue) ?? "A")
    }

    private func romanListMarker(for number: Int) -> String {
        var value = max(1, min(number, 3999))
        let numerals: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var result = ""

        for numeral in numerals {
            while value >= numeral.0 {
                result += numeral.1
                value -= numeral.0
            }
        }

        return result
    }

    private func integerValue(forLetterListMarker marker: String) -> Int {
        guard let scalar = marker.uppercased().unicodeScalars.first else { return 1 }
        return max(1, Int(scalar.value) - Int(("A" as UnicodeScalar).value) + 1)
    }

    private func integerValue(forRomanListMarker marker: String) -> Int {
        let values: [Character: Int] = [
            "I": 1,
            "V": 5,
            "X": 10,
            "L": 50,
            "C": 100,
            "D": 500,
            "M": 1000
        ]
        var total = 0
        var previous = 0

        for character in marker.uppercased().reversed() {
            let value = values[character] ?? 0
            if value < previous {
                total -= value
            } else {
                total += value
                previous = value
            }
        }

        return max(1, total)
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
