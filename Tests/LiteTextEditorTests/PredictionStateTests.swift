import XCTest
@testable import LiteTextEditor

final class PredictionStateTests: XCTestCase {
    func testIdleStateDoesNotProduceStatusText() {
        XCTAssertNil(PredictionState.idle.statusText)
    }

    func testPredictingStateProducesStatusText() {
        XCTAssertEqual(PredictionState.predicting.statusText, "Predicting...")
    }

    func testAvailableStateCountsSuggestionWords() {
        XCTAssertEqual(
            PredictionState.available(for: "other hand").statusText,
            "Prediction: 2 words"
        )
    }

    func testAvailableStateClampsEmptySuggestionsForDisplay() {
        XCTAssertEqual(
            PredictionState.available(for: "   ").statusText,
            "Prediction: 1 word"
        )
    }

    func testClearSuggestionPublishesIdleState() {
        let textView = AutocompleteTextView(frame: .zero, textContainer: nil)
        var publishedStates: [PredictionState] = []
        textView.currentSuggestion = "other hand"
        textView.suggestionLabel.stringValue = "other hand"
        textView.suggestionLabel.isHidden = false
        textView.onPredictionStateChanged = { publishedStates.append($0) }

        textView.clearSuggestion()

        XCTAssertEqual(publishedStates, [.idle])
        XCTAssertNil(textView.currentSuggestion)
        XCTAssertEqual(textView.suggestionLabel.stringValue, "")
        XCTAssertTrue(textView.suggestionLabel.isHidden)
    }

    func testSuggestionLabelWrapsPredictionsAcrossLines() {
        let textView = AutocompleteTextView(frame: .zero, textContainer: nil)

        XCTAssertEqual(textView.suggestionLabel.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(textView.suggestionLabel.maximumNumberOfLines, 3)
        XCTAssertEqual(textView.suggestionLabel.cell?.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(textView.suggestionLabel.cell?.wraps, true)
        XCTAssertEqual(textView.suggestionLabel.cell?.usesSingleLineMode, false)
    }

    func testRefreshSuggestionDoesNotPredictOverExistingDocumentText() {
        let provider = CountingSuggestionProvider(suggestion: "other hand")
        let textView = AutocompleteTextView(frame: .zero, textContainer: nil)
        textView.string = "This is on the page already"
        textView.setSelectedRange(NSRange(location: 14, length: 0))
        textView.suggestionProvider = provider

        textView.refreshSuggestion()

        XCTAssertEqual(provider.callCount, 0)
        XCTAssertNil(textView.currentSuggestion)
        XCTAssertTrue(textView.suggestionLabel.isHidden)
    }

    func testDisabledInlineSuggestionsDoNotRequestPredictions() {
        let provider = CountingSuggestionProvider(suggestion: "other hand")
        let textView = AutocompleteTextView(frame: .zero, textContainer: nil)
        textView.string = "This is on the"
        textView.setSelectedRange(NSRange(location: 14, length: 0))
        textView.suggestionProvider = provider
        textView.isInlineSuggestionEnabled = false

        textView.refreshSuggestion()

        XCTAssertEqual(provider.callCount, 0)
        XCTAssertNil(textView.currentSuggestion)
        XCTAssertTrue(textView.suggestionLabel.isHidden)
    }
}

private final class CountingSuggestionProvider: SuggestionProviding {
    private(set) var callCount = 0
    let suggestion: String?

    init(suggestion: String?) {
        self.suggestion = suggestion
    }

    func suggestion(for request: SuggestionRequest) -> String? {
        callCount += 1
        return suggestion
    }
}
