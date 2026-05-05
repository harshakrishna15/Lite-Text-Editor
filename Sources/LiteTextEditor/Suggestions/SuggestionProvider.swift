import Foundation

struct SuggestionRequest {
    let documentText: String
    let cursorLocation: Int
    let prefixContext: String
    let suffixContext: String
    let currentParagraph: String
    let documentContext: String
    let maxWords: Int

    var isAtSentenceBoundary: Bool {
        let trimmed = prefixContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return false }
        return ".!?".contains(last)
    }
}

protocol SuggestionProviding {
    func suggestion(for request: SuggestionRequest) -> String?
}

protocol AsyncSuggestionProviding: SuggestionProviding {
    func suggestion(for request: SuggestionRequest) async -> String?
}

extension SuggestionProviding {
    func asyncSuggestion(for request: SuggestionRequest) async -> String? {
        if let asyncProvider = self as? AsyncSuggestionProviding {
            return await asyncProvider.suggestion(for: request)
        }

        return suggestion(for: request)
    }
}

struct SuggestionPipeline: AsyncSuggestionProviding {
    let providers: [SuggestionProviding]

    func suggestion(for request: SuggestionRequest) -> String? {
        for provider in providers {
            if let suggestion = provider.suggestion(for: request) {
                return suggestion
            }
        }

        return nil
    }

    func suggestion(for request: SuggestionRequest) async -> String? {
        for provider in providers {
            if let suggestion = await provider.asyncSuggestion(for: request) {
                return suggestion
            }
        }

        return nil
    }
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

    private let nextWordMap: [String: [String]] = [
        "because": ["of the"],
        "although": ["this may"],
        "however": ["the main"],
        "therefore": ["we can"],
        "before": ["the next"],
        "after": ["the first"],
        "when": ["we look"],
        "while": ["this is"],
        "where": ["the main"],
        "why": ["this matters"]
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
              let candidates = nextWordMap[lastWord],
              let candidate = candidates.first else {
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
