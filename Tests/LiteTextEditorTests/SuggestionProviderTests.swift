import XCTest
@testable import LiteTextEditor

final class SuggestionProviderTests: XCTestCase {
    func testPipelineUsesFirstAvailableProvider() {
        let request = makeRequest(prefix: "Anything")
        let pipeline = SuggestionPipeline(
            providers: [
                StubSuggestionProvider(suggestion: nil),
                StubSuggestionProvider(suggestion: "first result"),
                StubSuggestionProvider(suggestion: "second result")
            ]
        )

        XCTAssertEqual(pipeline.suggestion(for: request), "first result")
    }

    func testPipelineReturnsNilWhenNoProviderCanSuggest() {
        let request = makeRequest(prefix: "Anything")
        let pipeline = SuggestionPipeline(
            providers: [
                StubSuggestionProvider(suggestion: nil),
                StubSuggestionProvider(suggestion: nil)
            ]
        )

        XCTAssertNil(pipeline.suggestion(for: request))
    }

    func testAsyncPipelineUsesFirstAvailableProvider() async {
        let request = makeRequest(prefix: "Anything")
        let pipeline = SuggestionPipeline(
            providers: [
                StubSuggestionProvider(suggestion: nil),
                StubSuggestionProvider(suggestion: "first result"),
                StubSuggestionProvider(suggestion: "second result")
            ]
        )

        let suggestion = await pipeline.suggestion(for: request)

        XCTAssertEqual(suggestion, "first result")
    }

    func testPhraseSuggestionEngineUsesKnownContinuation() {
        let request = makeRequest(prefix: "This is on the")

        XCTAssertEqual(PhraseSuggestionEngine().suggestion(for: request), "other hand")
    }

    func testPhraseSuggestionEngineDoesNotSuggestAfterPunctuation() {
        let request = makeRequest(prefix: "This sentence is done.")

        XCTAssertNil(PhraseSuggestionEngine().suggestion(for: request))
    }

    func testLocalAIProviderBuildsModelPromptWithoutReturningWhenUnloaded() {
        let request = makeRequest(prefix: "The next point is")
        let provider = LocalAISuggestionProvider()

        XCTAssertNil(provider.suggestion(for: request))
        XCTAssertFalse(provider.isReady)

        let prompt = provider.prompt(for: request)
        XCTAssertTrue(prompt.contains("Return only the next 2 to 4 words to insert."))
        XCTAssertTrue(prompt.contains("Do not repeat the words before [CURSOR]."))
        XCTAssertTrue(prompt.contains("Text immediately before cursor:"))
        XCTAssertTrue(prompt.contains("The next point is"))
    }

    func testLocalAIProviderLoadsGeneratorAndReturnsCleanedSuggestion() async throws {
        let request = makeRequest(prefix: "The current draft")
        let generator = StubLocalModelTextGenerator(
            rawCompletion: "\"Completion: The current draft should continue with details that are clipped\""
        )
        let provider = LocalAISuggestionProvider(generator: generator)

        XCTAssertFalse(provider.isReady)

        try await provider.load()

        XCTAssertTrue(provider.isReady)
        let synchronousSuggestion = (provider as SuggestionProviding).suggestion(for: request)
        let asynchronousSuggestion = await (provider as AsyncSuggestionProviding).suggestion(for: request)
        XCTAssertEqual(synchronousSuggestion, "should continue with details")
        XCTAssertEqual(asynchronousSuggestion, "should continue with details")
        XCTAssertEqual(generator.loadCallCount, 1)
        XCTAssertTrue(generator.lastPrompt?.contains("The current draft") == true)
    }

    func testLocalAIProviderFiltersOneWordModelOutput() async throws {
        let request = makeRequest(prefix: "The current draft")
        let generator = StubLocalModelTextGenerator(rawCompletion: "soon")
        let provider = LocalAISuggestionProvider(generator: generator)

        try await provider.load()

        let suggestion = (provider as SuggestionProviding).suggestion(for: request)
        XCTAssertNil(suggestion)
    }

    func testLocalAIProviderFiltersPrefixOnlyEcho() async throws {
        let request = makeRequest(prefix: "The current draft")
        let generator = StubLocalModelTextGenerator(rawCompletion: "The current draft")
        let provider = LocalAISuggestionProvider(generator: generator)

        try await provider.load()

        let suggestion = (provider as SuggestionProviding).suggestion(for: request)
        XCTAssertNil(suggestion)
    }

    func testLocalAIProviderStripsInstructionalModelWrappers() async throws {
        let request = makeRequest(prefix: "The current draft")
        let generator = StubLocalModelTextGenerator(
            rawCompletion: "The continuation is: should continue with details"
        )
        let provider = LocalAISuggestionProvider(generator: generator)

        try await provider.load()

        let suggestion = (provider as SuggestionProviding).suggestion(for: request)
        XCTAssertEqual(suggestion, "should continue with details")
    }

    func testEditorControllerAcceptsInjectedSuggestionProvider() {
        let request = makeRequest(prefix: "Custom providers")
        let controller = EditorController(
            suggestionProvider: StubSuggestionProvider(suggestion: "stay isolated")
        )

        XCTAssertEqual(controller.suggestionProvider.suggestion(for: request), "stay isolated")
    }

    func testEditorControllerUsesOnlyLocalAIByDefault() {
        let controller = EditorController()
        guard let pipeline = controller.suggestionProvider as? SuggestionPipeline else {
            XCTFail("Expected default suggestion provider to be a pipeline")
            return
        }

        XCTAssertEqual(pipeline.providers.count, 1)
        XCTAssertTrue(pipeline.providers[0] is LocalAISuggestionProvider)
    }

    func testDefaultPipelineReturnsNilWhenLocalAIIsUnloaded() {
        let request = makeRequest(prefix: "This is on the")
        let provider = LocalAISuggestionProvider(generator: UnavailableLocalModelTextGenerator())
        let pipeline = SuggestionPipeline(providers: [provider])

        XCTAssertNil(pipeline.suggestion(for: request))
    }

    private func makeRequest(prefix: String) -> SuggestionRequest {
        SuggestionRequest(
            documentText: prefix,
            cursorLocation: (prefix as NSString).length,
            prefixContext: prefix,
            suffixContext: "",
            currentParagraph: prefix,
            documentContext: prefix,
            maxWords: 4
        )
    }
}

private struct StubSuggestionProvider: SuggestionProviding {
    let suggestion: String?

    func suggestion(for request: SuggestionRequest) -> String? {
        suggestion
    }
}

private final class StubLocalModelTextGenerator: LocalModelTextGenerating {
    private(set) var isLoaded = false
    private(set) var loadCallCount = 0
    private(set) var lastPrompt: String?
    let rawCompletion: String?

    init(rawCompletion: String?) {
        self.rawCompletion = rawCompletion
    }

    func load() async throws {
        loadCallCount += 1
        isLoaded = true
    }

    func completion(for prompt: String) -> String? {
        lastPrompt = prompt
        return rawCompletion
    }
}
