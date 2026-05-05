import Foundation

protocol LocalModelSuggestionProviding: AsyncSuggestionProviding {
    var isReady: Bool { get }
    var modelName: String { get }
    func load() async throws
    func isDownloaded() async throws -> Bool
    func download(progressHandler: LocalModelDownloadProgressHandler?) async throws
    func uninstall() async throws
}

extension LocalModelSuggestionProviding {
    func download() async throws {
        try await download(progressHandler: nil)
    }
}

final class LocalAISuggestionProvider: LocalModelSuggestionProviding {
    private let generator: LocalModelTextGenerating
    private let postProcessor: LocalModelSuggestionPostProcessor

    var isReady: Bool {
        generator.isLoaded
    }

    var modelName: String {
        generator.modelName
    }

    init(
        generator: LocalModelTextGenerating = OllamaTextGenerator(),
        postProcessor: LocalModelSuggestionPostProcessor = LocalModelSuggestionPostProcessor()
    ) {
        self.generator = generator
        self.postProcessor = postProcessor
    }

    func load() async throws {
        try await generator.load()
    }

    func isDownloaded() async throws -> Bool {
        try await generator.isDownloaded()
    }

    func download(progressHandler: LocalModelDownloadProgressHandler?) async throws {
        try await generator.download(progressHandler: progressHandler)
    }

    func uninstall() async throws {
        try await generator.uninstall()
    }

    func suggestion(for request: SuggestionRequest) -> String? {
        guard isReady else { return nil }
        let prompt = prompt(for: request)
        guard let completion = generator.completion(for: prompt) else { return nil }
        return postProcessor.suggestion(from: completion, request: request)
    }

    func suggestion(for request: SuggestionRequest) async -> String? {
        if !isReady {
            try? await load()
        }

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
        Start with the first new word after the cursor.
        Do not repeat the text immediately before the cursor.
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
