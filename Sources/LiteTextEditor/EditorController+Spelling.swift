import AppKit

extension EditorController {
    func beginSpellingReview() {
        ignoredSpellingRanges.removeAll()
        advanceToNextSpellingIssue(startingAt: textView?.selectedRange().location ?? 0, wraps: true)
    }

    func applyCurrentSpellingCorrection() {
        guard let textView else { return }
        guard let range = spellCorrectionState.issueRange else {
            closeSpellingReview()
            return
        }

        guard let replacement = spellCorrectionState.selectedSuggestion, !replacement.isEmpty else {
            advanceToNextSpellingIssue(startingAt: NSMaxRange(range), wraps: true)
            return
        }

        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.undoManager?.setActionName("Spelling Correction")
        textView.breakUndoCoalescing()

        let nextLocation = range.location + (replacement as NSString).length
        advanceToNextSpellingIssue(startingAt: nextLocation, wraps: true)
    }

    func ignoreCurrentSpellingIssue() {
        guard let range = spellCorrectionState.issueRange else {
            closeSpellingReview()
            return
        }

        ignoredSpellingRanges.append(range)
        advanceToNextSpellingIssue(startingAt: NSMaxRange(range), wraps: true)
    }

    func closeSpellingReview() {
        spellCorrectionState = .inactive
        textView?.isSpellingCorrectionReviewActive = false
    }

    func selectSpellingSuggestion(at index: Int) {
        guard spellCorrectionState.suggestions.indices.contains(index) else { return }
        spellCorrectionState.selectedSuggestionIndex = index
    }

    func moveSpellingSuggestionSelection(by delta: Int) {
        guard !spellCorrectionState.suggestions.isEmpty else { return }

        let lastIndex = spellCorrectionState.suggestions.count - 1
        let nextIndex = min(max(spellCorrectionState.selectedSuggestionIndex + delta, 0), lastIndex)

        if nextIndex != spellCorrectionState.selectedSuggestionIndex {
            spellCorrectionState.selectedSuggestionIndex = nextIndex
        }
    }

    private func advanceToNextSpellingIssue(startingAt location: Int, wraps: Bool) {
        guard let textView else { return }

        guard let issue = findNextSpellingIssue(startingAt: location, wraps: wraps) else {
            spellCorrectionState = .complete
            textView.isSpellingCorrectionReviewActive = true
            return
        }

        textView.isSpellingCorrectionReviewActive = true
        textView.setSelectedRange(issue.range)
        textView.scrollRangeToVisible(issue.range)
        textView.window?.makeFirstResponder(textView)

        spellCorrectionState = SpellCorrectionState(
            isPresented: true,
            issueRange: issue.range,
            originalWord: issue.word,
            suggestions: issue.suggestions,
            selectedSuggestionIndex: 0,
            statusText: "Possible spelling issue"
        )
    }

    private func findNextSpellingIssue(startingAt location: Int, wraps: Bool) -> SpellingIssue? {
        guard let textView else { return nil }

        let text = textView.string
        let nsString = text as NSString
        guard nsString.length > 0 else { return nil }

        let checker = NSSpellChecker.shared
        let originalStart = min(max(location, 0), nsString.length)
        var searchStart = originalStart
        var didWrap = false

        while true {
            var wordCount = 0
            let range = checker.checkSpelling(
                of: text,
                startingAt: searchStart,
                language: nil,
                wrap: false,
                inSpellDocumentWithTag: spellingDocumentTag,
                wordCount: &wordCount
            )

            if range.location != NSNotFound, range.length > 0 {
                if !isIgnoredSpellingRange(range) {
                    let word = nsString.substring(with: range)
                    let guesses = checker.guesses(
                        forWordRange: range,
                        in: text,
                        language: nil,
                        inSpellDocumentWithTag: spellingDocumentTag
                    ) ?? []

                    return SpellingIssue(range: range, word: word, suggestions: Array(guesses.prefix(5)))
                }

                let nextStart = NSMaxRange(range)
                if nextStart < nsString.length {
                    searchStart = nextStart
                    continue
                }
            }

            guard wraps, !didWrap, originalStart > 0 else {
                return nil
            }

            searchStart = 0
            didWrap = true
        }
    }

    private func isIgnoredSpellingRange(_ range: NSRange) -> Bool {
        ignoredSpellingRanges.contains { ignoredRange in
            NSEqualRanges(ignoredRange, range)
        }
    }
}

private struct SpellingIssue {
    let range: NSRange
    let word: String
    let suggestions: [String]
}
