import Foundation

struct ComboBoxCompletionResolver {
    struct Decision: Equatable {
        let text: String
        let selectedRange: NSRange
        let completed: Bool
    }

    func decision(
        typedText: String,
        previousText: String,
        previousSelectionRange: NSRange,
        shouldSkipCompletion: Bool,
        items: [String]
    ) -> Decision {
        let typedLength = (typedText as NSString).length

        guard !shouldSkipCompletion,
              !isDeletionEdit(
                typedText: typedText,
                previousText: previousText,
                previousSelectionRange: previousSelectionRange
              ),
              !typedText.isEmpty else {
            return Decision(
                text: typedText,
                selectedRange: NSRange(location: typedLength, length: 0),
                completed: false
            )
        }

        guard let completion = items.first(where: { item in
            item.range(
                of: typedText,
                options: [.caseInsensitive, .diacriticInsensitive, .anchored]
            ) != nil
        }) else {
            return Decision(
                text: typedText,
                selectedRange: NSRange(location: typedLength, length: 0),
                completed: false
            )
        }

        let completionLength = (completion as NSString).length
        guard completionLength > typedLength else {
            return Decision(
                text: typedText,
                selectedRange: NSRange(location: typedLength, length: 0),
                completed: false
            )
        }

        return Decision(
            text: completion,
            selectedRange: NSRange(
                location: typedLength,
                length: completionLength - typedLength
            ),
            completed: true
        )
    }

    private func isDeletionEdit(
        typedText: String,
        previousText: String,
        previousSelectionRange: NSRange
    ) -> Bool {
        guard previousSelectionRange.length == 0 else { return false }
        let typedLength = (typedText as NSString).length
        let previousLength = (previousText as NSString).length
        return typedLength < previousLength
    }
}
