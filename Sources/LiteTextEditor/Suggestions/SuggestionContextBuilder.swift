import Foundation

struct SuggestionContextBuilder {
    var maxPrefixCharacters = 900
    var maxSuffixCharacters = 500
    var maxDocumentLeadingCharacters = 2_400
    var maxDocumentTrailingCharacters = 900
    var minimumWords = 2
    var maximumWords = 5

    func request(
        documentText: String,
        selectedRange: NSRange,
        maxSuggestionWords: Int
    ) -> SuggestionRequest {
        let nsString = documentText as NSString
        let safeCursor = min(max(selectedRange.location, 0), nsString.length)
        let prefixLength = min(safeCursor, maxPrefixCharacters)
        let suffixLength = min(nsString.length - safeCursor, maxSuffixCharacters)
        let prefixStart = safeCursor - prefixLength
        let paragraphRange = paragraphRange(around: safeCursor, in: nsString)
        let documentContext = compactDocumentContext(from: nsString, cursorLocation: safeCursor)

        return SuggestionRequest(
            documentText: documentContext,
            cursorLocation: safeCursor,
            prefixContext: nsString.substring(with: NSRange(location: prefixStart, length: prefixLength)),
            suffixContext: nsString.substring(with: NSRange(location: safeCursor, length: suffixLength)),
            currentParagraph: nsString.substring(with: paragraphRange),
            documentContext: documentContext,
            maxWords: max(minimumWords, min(maxSuggestionWords, maximumWords))
        )
    }

    private func paragraphRange(around location: Int, in nsString: NSString) -> NSRange {
        guard nsString.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let safeLocation = min(max(location, 0), nsString.length - 1)
        return nsString.paragraphRange(for: NSRange(location: safeLocation, length: 0))
    }

    private func compactDocumentContext(from nsString: NSString, cursorLocation: Int) -> String {
        let leadingLength = min(cursorLocation, maxDocumentLeadingCharacters)
        let trailingLength = min(nsString.length - cursorLocation, maxDocumentTrailingCharacters)
        let leadingStart = cursorLocation - leadingLength

        let leading = nsString.substring(with: NSRange(location: leadingStart, length: leadingLength))
        let trailing = nsString.substring(with: NSRange(location: cursorLocation, length: trailingLength))

        if trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return leading
        }

        return """
        \(leading)
        [CURSOR]
        \(trailing)
        """
    }
}
