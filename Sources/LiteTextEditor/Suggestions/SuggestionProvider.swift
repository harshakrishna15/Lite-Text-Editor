import Foundation

struct SuggestionRequest {
    let prefixContext: String
    let maxWords: Int
}

protocol SuggestionProviding {
    func suggestion(for request: SuggestionRequest) -> String?
}

struct PhraseSuggestionEngine: SuggestionProviding {
    private let phraseMap: [(trigger: String, completion: String)] = [
        ("on the", "other hand"),
        ("as a", "result of this"),
        ("in order", "to make sure"),
        ("the purpose", "of this is"),
        ("at the end", "of the day"),
        ("it is", "important to note"),
        ("this means", "that we can"),
        ("for example", "we can see"),
        ("in this", "case the result"),
        ("the main", "reason is that"),
        ("one of", "the most important"),
        ("from my", "point of view"),
        ("in the", "middle of the"),
        ("the next", "step is to"),
        ("this shows", "that the")
    ]

    private let nextWordMap: [String: String] = [
        "because": "of the",
        "although": "this may",
        "however": "the main",
        "therefore": "we can",
        "before": "the next",
        "after": "the first",
        "when": "we look",
        "while": "this is",
        "where": "the main",
        "why": "this matters"
    ]

    func suggestion(for request: SuggestionRequest) -> String? {
        let normalized = normalize(request.prefixContext)
        guard !normalized.isEmpty else { return nil }

        if normalized.last?.isPunctuation == true {
            return nil
        }

        for phrase in phraseMap where normalized.hasSuffix(phrase.trigger) {
            return clipped(phrase.completion, maxWords: request.maxWords)
        }

        guard let lastWord = normalized.split(separator: " ").last.map(String.init),
              let candidate = nextWordMap[lastWord] else {
            return nil
        }

        return clipped(candidate, maxWords: request.maxWords)
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clipped(_ suggestion: String, maxWords: Int) -> String? {
        let words = suggestion.split(separator: " ")
        guard words.count >= 2 else { return nil }

        return words
            .prefix(min(maxWords, 5))
            .joined(separator: " ")
    }
}
