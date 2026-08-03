import AppKit
import XCTest
@testable import LiteTextEditor

final class PredictionStateTests: XCTestCase {
    func testIdleStateDoesNotProduceStatusText() {
        XCTAssertNil(PredictionState.idle.statusText)
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

    func testSuggestionGhostUsesCurrentTypingAttributes() throws {
        let textView = AutocompleteTextView(frame: .zero, textContainer: nil)
        let font = NSFont.systemFont(ofSize: 18, weight: .bold)
        let foregroundColor = NSColor(deviceRed: 0.8, green: 0.1, blue: 0.2, alpha: 1)
        let backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.35
        paragraphStyle.paragraphSpacing = 8

        textView.typingAttributes = [
            .font: font,
            .foregroundColor: foregroundColor,
            .backgroundColor: backgroundColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .kern: CGFloat(1.5),
            .baselineOffset: CGFloat(2),
            .paragraphStyle: paragraphStyle
        ]

        let ghost = textView.attributedSuggestion(for: "other hand")
        let attributes = ghost.attributes(at: 0, effectiveRange: nil)

        XCTAssertEqual((attributes[.font] as? NSFont)?.fontName, font.fontName)
        XCTAssertEqual((attributes[.font] as? NSFont)?.pointSize, font.pointSize)
        XCTAssertEqual(attributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attributes[.strikethroughStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attributes[.kern] as? CGFloat, 1.5)
        XCTAssertEqual(attributes[.baselineOffset] as? CGFloat, 2)

        let ghostParagraphStyle = try XCTUnwrap(attributes[.paragraphStyle] as? NSParagraphStyle)
        XCTAssertEqual(ghostParagraphStyle.lineHeightMultiple, paragraphStyle.lineHeightMultiple)
        XCTAssertEqual(ghostParagraphStyle.paragraphSpacing, paragraphStyle.paragraphSpacing)

        let ghostForegroundColor = try XCTUnwrap(attributes[.foregroundColor] as? NSColor)
        XCTAssertEqual(ghostForegroundColor.alphaComponent, 0.42, accuracy: 0.001)
        let foregroundRGB = try XCTUnwrap(ghostForegroundColor.usingColorSpace(.deviceRGB))
        XCTAssertEqual(foregroundRGB.redComponent, 0.8, accuracy: 0.001)
        XCTAssertEqual(foregroundRGB.greenComponent, 0.1, accuracy: 0.001)
        XCTAssertEqual(foregroundRGB.blueComponent, 0.2, accuracy: 0.001)

        let ghostBackgroundColor = try XCTUnwrap(attributes[.backgroundColor] as? NSColor)
        XCTAssertEqual(ghostBackgroundColor.alphaComponent, 0.22, accuracy: 0.001)
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

    func testRefreshSuggestionDoesNotPredictBeforeFiftyWords() {
        let provider = CountingSuggestionProvider(suggestion: "other hand")
        let textView = makeTextView(repeatedWords(49))
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.suggestionProvider = provider

        textView.refreshSuggestion()

        XCTAssertEqual(provider.callCount, 0)
        XCTAssertNil(textView.currentSuggestion)
        XCTAssertTrue(textView.suggestionLabel.isHidden)
    }

    func testRefreshSuggestionPredictsAtFiftyWords() {
        let provider = CountingSuggestionProvider(suggestion: "other hand")
        let textView = makeTextView(repeatedWords(50))
        var publishedStates: [PredictionState] = []
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.suggestionProvider = provider
        textView.onPredictionStateChanged = { publishedStates.append($0) }
        XCTAssertTrue(textView.hasEnoughWordsBeforeInsertionPoint())

        textView.refreshSuggestion()

        XCTAssertEqual(provider.callCount, 1)
        XCTAssertTrue(publishedStates.contains(.available(wordCount: 2)))
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

    private func repeatedWords(_ count: Int) -> String {
        (0..<count)
            .map { _ in "word" }
            .joined(separator: " ")
    }

    private func makeTextView(_ text: String) -> AutocompleteTextView {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: AutocompleteTextView.pageTextWidth,
                height: AutocompleteTextView.textLayoutDimensionLimit
            )
        )
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        return AutocompleteTextView(frame: .zero, textContainer: textContainer)
    }
}

private final class CountingSuggestionProvider: SuggestionProviding {
    private(set) var callCount = 0
    let suggestion: String?
    let onCall: (() -> Void)?

    init(suggestion: String?, onCall: (() -> Void)? = nil) {
        self.suggestion = suggestion
        self.onCall = onCall
    }

    func suggestion(for request: SuggestionRequest) -> String? {
        callCount += 1
        onCall?()
        return suggestion
    }
}
