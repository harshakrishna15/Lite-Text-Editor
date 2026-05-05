import Foundation

protocol LocalModelSuggestionProviding: AsyncSuggestionProviding {
    var isReady: Bool { get }
    func load() async throws
}

final class LocalAISuggestionProvider: LocalModelSuggestionProviding {
    private let generator: LocalModelTextGenerating
    private let postProcessor: LocalModelSuggestionPostProcessor

    var isReady: Bool {
        generator.isLoaded
    }

    init(
        generator: LocalModelTextGenerating = UnavailableLocalModelTextGenerator(),
        postProcessor: LocalModelSuggestionPostProcessor = LocalModelSuggestionPostProcessor()
    ) {
        self.generator = generator
        self.postProcessor = postProcessor
    }

    func load() async throws {
        try await generator.load()
    }

    func suggestion(for request: SuggestionRequest) -> String? {
        guard isReady else { return nil }
        let prompt = prompt(for: request)
        guard let completion = generator.completion(for: prompt) else { return nil }
        return postProcessor.suggestion(from: completion, request: request)
    }

    func suggestion(for request: SuggestionRequest) async -> String? {
        guard isReady else { return nil }

        let prompt = prompt(for: request)
        let generator = generator
        let postProcessor = postProcessor

        return await Task.detached(priority: .userInitiated) {
            guard let completion = generator.completion(for: prompt) else { return nil }
            return postProcessor.suggestion(from: completion, request: request)
        }.value
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
