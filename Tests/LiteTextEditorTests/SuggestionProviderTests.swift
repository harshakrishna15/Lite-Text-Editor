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

    func testEditorControllerAcceptsInjectedSuggestionProvider() {
        let request = makeRequest(prefix: "Custom providers")
        let controller = EditorController(
            suggestionProvider: StubSuggestionProvider(suggestion: "stay isolated")
        )

        XCTAssertEqual(controller.suggestionProvider.suggestion(for: request), "stay isolated")
    }

    func testEditorControllerUsesPhraseSuggestionsByDefault() {
        let controller = EditorController()
        guard let pipeline = controller.suggestionProvider as? SuggestionPipeline else {
            XCTFail("Expected default suggestion provider to be a pipeline")
            return
        }

        XCTAssertEqual(pipeline.providers.count, 1)
        XCTAssertTrue(pipeline.providers[0] is PhraseSuggestionEngine)
        XCTAssertEqual(pipeline.suggestion(for: makeRequest(prefix: "This is on the")), "other hand")
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
