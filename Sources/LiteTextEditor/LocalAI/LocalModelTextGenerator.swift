import Foundation

protocol LocalModelTextGenerating: AnyObject {
    var isLoaded: Bool { get }
    func load() async throws
    func completion(for prompt: String) -> String?
}

final class UnavailableLocalModelTextGenerator: LocalModelTextGenerating {
    var isLoaded: Bool { false }

    func load() async throws {}

    func completion(for prompt: String) -> String? {
        nil
    }
}

struct LocalModelSuggestionPostProcessor {
    func suggestion(from rawCompletion: String, request: SuggestionRequest) -> String? {
        let cleaned = clean(rawCompletion)
        guard !cleaned.isEmpty else { return nil }

        let suffixOnly = removingRepeatedPrefix(from: cleaned, request: request)
        let words = suffixOnly
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard words.count >= 2 else { return nil }

        let clipped = words
            .prefix(request.maxWords)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return clipped.isEmpty ? nil : clipped
    }

    private func clean(_ rawCompletion: String) -> String {
        let firstLine = rawCompletion
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""

        let unwrapped = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return strippingKnownLabel(from: unwrapped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func strippingKnownLabel(from text: String) -> String {
        let labels = ["Completion:", "Suggestion:", "Answer:"]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercased = trimmed.lowercased()

        for label in labels where lowercased.hasPrefix(label.lowercased()) {
            return String(trimmed.dropFirst(label.count))
        }

        return trimmed
    }

    private func removingRepeatedPrefix(from completion: String, request: SuggestionRequest) -> String {
        let prefixWords = request.prefixContext
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !prefixWords.isEmpty else { return completion }

        let completionWords = completion
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard completionWords.count > prefixWords.count else { return completion }

        for triggerLength in stride(from: min(prefixWords.count, completionWords.count - 1), through: 1, by: -1) {
            let prefixTail = prefixWords.suffix(triggerLength).map(normalizedWord)
            let completionHead = completionWords.prefix(triggerLength).map(normalizedWord)

            if prefixTail == completionHead {
                return completionWords.dropFirst(triggerLength).joined(separator: " ")
            }
        }

        return completion
    }

    private func normalizedWord(_ word: String) -> String {
        word
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
    }
}
