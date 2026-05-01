import AppKit

struct SpellingIssue {
    let range: NSRange
    let word: String
    let suggestions: [String]
}

final class SpellingReviewController {
    private let spellDocumentTag = NSSpellChecker.uniqueSpellDocumentTag()
    private var ignoredRanges: [NSRange] = []

    func resetIgnoredIssues() {
        ignoredRanges.removeAll()
    }

    func ignore(_ range: NSRange) {
        ignoredRanges.append(range)
    }

    func nextIssue(in text: String, startingAt location: Int, wraps: Bool) -> SpellingIssue? {
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
                inSpellDocumentWithTag: spellDocumentTag,
                wordCount: &wordCount
            )

            if range.location != NSNotFound, range.length > 0 {
                if !isIgnored(range) {
                    let word = nsString.substring(with: range)
                    let guesses = checker.guesses(
                        forWordRange: range,
                        in: text,
                        language: nil,
                        inSpellDocumentWithTag: spellDocumentTag
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

    private func isIgnored(_ range: NSRange) -> Bool {
        ignoredRanges.contains { ignoredRange in
            NSEqualRanges(ignoredRange, range)
        }
    }
}
