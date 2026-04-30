import Foundation

protocol LocalModelSuggestionProviding: SuggestionProviding {
    var isReady: Bool { get }
    func load() async throws
}

final class LocalAISuggestionProvider: LocalModelSuggestionProviding {
    private(set) var isReady = false

    func load() async throws {
        // MLX Swift LM will be wired here after the editor interaction is stable.
        // Keeping this boundary now prevents the UI from depending on a specific model.
        isReady = false
    }

    func suggestion(for request: SuggestionRequest) -> String? {
        guard isReady else { return nil }
        _ = prompt(for: request)
        return nil
    }

    func prompt(for request: SuggestionRequest) -> String {
        """
        You are Lite Text Editor, a local autocomplete engine for a WYSIWYG writing editor.
        Continue the text at the cursor using the current document context.
        Return only the next \(request.maxWordsRangeDescription) words.
        Do not rewrite existing text.
        Do not explain.
        Do not add quotes around the answer.
        Match the document's tone, tense, vocabulary, and subject matter.

        Current document context:
        \(request.documentContext)

        Current paragraph:
        \(request.currentParagraph)

        Text immediately before cursor:
        \(request.prefixContext)

        Text immediately after cursor:
        \(request.suffixContext)

        Completion:
        """
    }
}

private extension SuggestionRequest {
    var maxWordsRangeDescription: String {
        "2 to \(maxWords)"
    }
}
