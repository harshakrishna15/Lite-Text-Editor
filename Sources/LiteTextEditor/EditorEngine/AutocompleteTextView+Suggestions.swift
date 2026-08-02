import AppKit

enum SuggestionLabelLayout {
    static let leadingOffset: CGFloat = 3
    static let horizontalPadding: CGFloat = 8
    static let edgePadding: CGFloat = 6
    static let verticalOffset: CGFloat = 2

    static func frame(
        anchorPoint: NSPoint,
        fittingSize: NSSize,
        visibleRect: NSRect,
        maximumWidth: CGFloat? = nil
    ) -> NSRect {
        let visibleWidth = max(0, visibleRect.width - (edgePadding * 2))
        let availableWidth = maximumWidth.map { min(visibleWidth, max(0, $0)) } ?? visibleWidth
        let width = min(fittingSize.width + horizontalPadding, availableWidth)
        let height = fittingSize.height
        let minX = visibleRect.minX + edgePadding
        let maxX = max(minX, visibleRect.maxX - width - edgePadding)
        let x = min(max(anchorPoint.x + leadingOffset, minX), maxX)
        let minY = visibleRect.minY
        let maxY = max(minY, visibleRect.maxY - height)
        let y = min(max(anchorPoint.y - height + verticalOffset, minY), maxY)

        return NSRect(x: x, y: y, width: width, height: height)
    }
}

extension AutocompleteTextView {
    static let minimumWordsBeforePrediction = 50

    func refreshSuggestion() {
        pendingSuggestionRefreshWorkItem?.cancel()
        pendingSuggestionRefreshWorkItem = nil
        pendingSuggestionTask?.cancel()
        pendingSuggestionTask = nil

        let refreshKey = suggestionRefreshKey()
        lastSuggestionRefreshKey = refreshKey

        guard isInlineSuggestionEnabled else {
            clearSuggestion()
            return
        }

        guard selectedRange().length == 0 else {
            clearSuggestion()
            return
        }

        guard canShowPredictionAtInsertionPoint() else {
            clearSuggestion()
            return
        }

        guard hasEnoughWordsBeforeInsertionPoint() else {
            clearSuggestion()
            return
        }

        let request = makeSuggestionRequest()
        let provider = suggestionProvider
        clearSuggestion()
        publishPredictionState(.predicting)

        pendingSuggestionTask = Task { [weak self] in
            let suggestion = await provider.asyncSuggestion(for: request)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                guard self.suggestionRefreshKey() == refreshKey else { return }

                self.pendingSuggestionTask = nil
                guard let suggestion else {
                    self.clearSuggestion()
                    return
                }

                self.showSuggestion(suggestion)
            }
        }
    }

    func acceptSuggestion() {
        acceptNextSuggestionWord()
    }

    func acceptNextSuggestionWord() {
        guard let suggestion = currentSuggestion else { return }
        var words = suggestion.split(separator: " ").map(String.init)
        guard !words.isEmpty else {
            clearSuggestion()
            return
        }

        let firstWord = words.removeFirst()

        isAcceptingSuggestionWord = true
        insertText(textToInsert(for: firstWord), replacementRange: selectedRange())
        isAcceptingSuggestionWord = false

        if words.isEmpty {
            clearSuggestion()
            refreshSuggestion()
        } else {
            showSuggestion(words.joined(separator: " "))
        }
    }

    func configureSuggestionLabel() {
        drawsBackground = false
        backgroundColor = .clear
        suggestionLabel.isHidden = true
        suggestionLabel.isEditable = false
        suggestionLabel.isSelectable = false
        suggestionLabel.drawsBackground = false
        suggestionLabel.isBordered = false
        suggestionLabel.textColor = ghostSuggestionForegroundColor(for: nil)
        suggestionLabel.font = defaultSuggestionFont
        suggestionLabel.lineBreakMode = .byWordWrapping
        suggestionLabel.maximumNumberOfLines = 3
        suggestionLabel.cell?.lineBreakMode = .byWordWrapping
        suggestionLabel.cell?.wraps = true
        suggestionLabel.cell?.isScrollable = false
        suggestionLabel.cell?.usesSingleLineMode = false
        suggestionLabel.wantsLayer = true
        addSubview(suggestionLabel)
    }

    func scheduleSuggestionRefresh() {
        guard isInlineSuggestionEnabled else {
            clearSuggestion()
            return
        }

        let scheduledKey = suggestionRefreshKey()
        guard scheduledKey != lastSuggestionRefreshKey else { return }

        pendingSuggestionTask?.cancel()
        pendingSuggestionTask = nil
        if currentSuggestion != nil {
            clearSuggestion()
        }

        pendingSuggestionRefreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSuggestionRefreshWorkItem = nil
            guard self.suggestionRefreshKey() != self.lastSuggestionRefreshKey else { return }
            self.refreshSuggestion()
        }

        pendingSuggestionRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.suggestionRefreshDelay, execute: workItem)
    }

    func clearSuggestion() {
        pendingSuggestionTask?.cancel()
        pendingSuggestionTask = nil
        publishPredictionState(.idle)

        guard currentSuggestion != nil || !suggestionLabel.isHidden || !suggestionLabel.stringValue.isEmpty else {
            return
        }

        currentSuggestion = nil
        suggestionLabel.stringValue = ""
        suggestionLabel.isHidden = true
    }

    private func suggestionRefreshKey() -> SuggestionRefreshKey {
        let selection = selectedRange()

        return SuggestionRefreshKey(
            selectionLocation: selection.location,
            selectionLength: selection.length,
            stringLength: textStorageLength,
            contentGeneration: contentGeneration,
            maxSuggestionWords: maxSuggestionWords,
            isInlineSuggestionEnabled: isInlineSuggestionEnabled
        )
    }

    private func showSuggestion(_ suggestion: String) {
        guard canShowPredictionAtInsertionPoint() else {
            clearSuggestion()
            return
        }

        let previousSuggestion = currentSuggestion
        let previousAttributedSuggestion = suggestionLabel.attributedStringValue
        let nextAttributedSuggestion = attributedSuggestion(for: suggestion)
        let shouldUpdateAttributedSuggestion = !previousAttributedSuggestion.isEqual(to: nextAttributedSuggestion)

        currentSuggestion = suggestion
        if shouldUpdateAttributedSuggestion {
            suggestionLabel.attributedStringValue = nextAttributedSuggestion
        }

        if previousSuggestion != suggestion || shouldUpdateAttributedSuggestion {
            suggestionLabel.invalidateIntrinsicContentSize()
        }

        suggestionLabel.isHidden = false
        positionSuggestionLabel()
        publishPredictionState(.available(for: suggestion))
    }

    private func publishPredictionState(_ state: PredictionState) {
        onPredictionStateChanged?(state)
    }

    private func canShowPredictionAtInsertionPoint() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let nsString = string as NSString
        guard selection.location < nsString.length else { return true }

        let suffix = nsString.substring(from: selection.location)
        return suffix.unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0)
        }
    }

    private func contextBeforeInsertionPoint() -> String {
        let location = selectedRange().location
        let nsString = string as NSString
        let length = min(location, 500)
        let start = max(0, location - length)
        return nsString.substring(with: NSRange(location: start, length: length))
    }

    func hasEnoughWordsBeforeInsertionPoint(
        minimumWords: Int = AutocompleteTextView.minimumWordsBeforePrediction
    ) -> Bool {
        let location = min(max(selectedRange().location, 0), (string as NSString).length)
        guard location > 0 else { return false }

        let nsString = string as NSString
        let prefix = nsString.substring(to: location)
        var wordCount = 0
        var isInsideWord = false

        for scalar in prefix.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if !isInsideWord {
                    wordCount += 1
                    if wordCount >= minimumWords {
                        return true
                    }

                    isInsideWord = true
                }
            } else {
                isInsideWord = false
            }
        }

        return false
    }

    private func makeSuggestionRequest() -> SuggestionRequest {
        SuggestionContextBuilder().request(
            documentText: string,
            selectedRange: selectedRange(),
            maxSuggestionWords: maxSuggestionWords
        )
    }

    private func textToInsert(for suggestion: String) -> String {
        let needsLeadingSpace = !(contextBeforeInsertionPoint().last?.isWhitespace ?? true)
        return needsLeadingSpace ? " \(suggestion)" : suggestion
    }

    func attributedSuggestion(for suggestion: String) -> NSAttributedString {
        var attributes = typingAttributes

        if attributes[.font] == nil {
            attributes[.font] = defaultSuggestionFont
        }

        attributes[.foregroundColor] = ghostSuggestionForegroundColor(
            for: attributes[.foregroundColor] as? NSColor
        )

        if let backgroundColor = attributes[.backgroundColor] as? NSColor {
            attributes[.backgroundColor] = backgroundColor.withAlphaComponent(
                min(backgroundColor.alphaComponent, 0.22)
            )
        }

        return NSAttributedString(string: suggestion, attributes: attributes)
    }

    private var defaultSuggestionFont: NSFont {
        EditorTypography.font(size: EditorTypography.defaultPointSize)
    }

    private func ghostSuggestionForegroundColor(for color: NSColor?) -> NSColor {
        let baseColor = color ?? .tertiaryLabelColor
        return baseColor.withAlphaComponent(min(baseColor.alphaComponent, 0.42))
    }

    private func positionSuggestionLabel() {
        guard !suggestionLabel.isHidden else { return }

        let insertionRange = selectedRange()
        guard let window else { return }

        let screenRect = firstRect(forCharacterRange: insertionRange, actualRange: nil)
        let windowPoint = window.convertPoint(fromScreen: screenRect.origin)
        let localPoint = convert(windowPoint, from: nil)
        let maximumWidth = maximumSuggestionLabelWidth(from: localPoint)

        suggestionLabel.preferredMaxLayoutWidth = max(
            1,
            maximumWidth - SuggestionLabelLayout.horizontalPadding
        )
        let labelSize = suggestionLabel.fittingSize

        suggestionLabel.frame = SuggestionLabelLayout.frame(
            anchorPoint: localPoint,
            fittingSize: labelSize,
            visibleRect: visibleRect,
            maximumWidth: maximumWidth
        )
    }

    private func maximumSuggestionLabelWidth(from anchorPoint: NSPoint) -> CGFloat {
        let textRightEdge = textContainerOrigin.x + (textContainer?.containerSize.width ?? Self.pageTextWidth)
        return max(0, textRightEdge - anchorPoint.x - SuggestionLabelLayout.leadingOffset)
    }
}
