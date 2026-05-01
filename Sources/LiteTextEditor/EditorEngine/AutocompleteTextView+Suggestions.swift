import AppKit

extension AutocompleteTextView {
    func refreshSuggestion() {
        pendingSuggestionRefreshWorkItem?.cancel()
        pendingSuggestionRefreshWorkItem = nil
        lastSuggestionRefreshKey = suggestionRefreshKey()

        guard selectedRange().length == 0 else {
            clearSuggestion()
            return
        }

        let request = makeSuggestionRequest()
        let suggestion = suggestionProvider.suggestion(for: request)

        guard let suggestion else {
            clearSuggestion()
            return
        }

        showSuggestion(suggestion)
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
        suggestionLabel.textColor = .tertiaryLabelColor
        suggestionLabel.font = .systemFont(ofSize: 11)
        suggestionLabel.wantsLayer = true
        addSubview(suggestionLabel)
    }

    func scheduleSuggestionRefresh() {
        let scheduledKey = suggestionRefreshKey()
        guard scheduledKey != lastSuggestionRefreshKey else { return }

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
            stringLength: (string as NSString).length,
            contentGeneration: contentGeneration,
            maxSuggestionWords: maxSuggestionWords
        )
    }

    private func showSuggestion(_ suggestion: String) {
        let previousSuggestion = currentSuggestion
        let previousFont = suggestionLabel.font
        let nextFont = typingAttributes[.font] as? NSFont

        currentSuggestion = suggestion
        if suggestionLabel.stringValue != suggestion {
            suggestionLabel.stringValue = suggestion
        }

        if let typingFont = nextFont, previousFont != typingFont {
            suggestionLabel.font = typingFont
        }

        if previousSuggestion != suggestion || previousFont != suggestionLabel.font {
            suggestionLabel.sizeToFit()
        }

        suggestionLabel.isHidden = false
        positionSuggestionLabel()
    }

    private func contextBeforeInsertionPoint() -> String {
        let location = selectedRange().location
        let nsString = string as NSString
        let length = min(location, 500)
        let start = max(0, location - length)
        return nsString.substring(with: NSRange(location: start, length: length))
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

    private func positionSuggestionLabel() {
        guard !suggestionLabel.isHidden else { return }

        let insertionRange = selectedRange()
        guard let window else { return }

        let screenRect = firstRect(forCharacterRange: insertionRange, actualRange: nil)
        let windowPoint = window.convertPoint(fromScreen: screenRect.origin)
        let localPoint = convert(windowPoint, from: nil)
        let labelSize = suggestionLabel.fittingSize

        suggestionLabel.frame = NSRect(
            x: localPoint.x + 3,
            y: max(localPoint.y - labelSize.height + 2, visibleRect.minY),
            width: labelSize.width + 8,
            height: labelSize.height
        )
    }
}
