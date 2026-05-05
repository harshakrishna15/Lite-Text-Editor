import AppKit

extension EditorController {
    func beginSpellingReview() {
        spellingReviewController.resetIgnoredIssues()
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

        let nsString = textView.string as NSString
        guard NSMaxRange(range) <= nsString.length,
              nsString.substring(with: range) == spellCorrectionState.originalWord else {
            advanceToNextSpellingIssue(startingAt: min(range.location, nsString.length), wraps: true)
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

        spellingReviewController.ignore(range)
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

        guard let issue = spellingReviewController.nextIssue(
            in: textView.string,
            startingAt: location,
            wraps: wraps
        ) else {
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
}
