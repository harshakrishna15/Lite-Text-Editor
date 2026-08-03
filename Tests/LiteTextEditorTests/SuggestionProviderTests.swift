import XCTest
@testable import LiteTextEditor

final class SuggestionProviderTests: XCTestCase {
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

        XCTAssertTrue(controller.suggestionProvider is PhraseSuggestionEngine)
        XCTAssertEqual(
            controller.suggestionProvider.suggestion(for: makeRequest(prefix: "This is on the")),
            "other hand"
        )
    }

    private func makeRequest(prefix: String) -> SuggestionRequest {
        SuggestionRequest(
            prefixContext: prefix,
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
