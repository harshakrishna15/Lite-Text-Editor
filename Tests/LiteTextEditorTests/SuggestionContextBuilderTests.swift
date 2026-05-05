import XCTest
@testable import LiteTextEditor

final class SuggestionContextBuilderTests: XCTestCase {
    func testLongSuggestionLabelDoesNotExtendPastVisibleRightEdge() {
        let visibleRect = NSRect(x: 20, y: 10, width: 240, height: 120)

        let frame = SuggestionLabelLayout.frame(
            anchorPoint: NSPoint(x: 235, y: 80),
            fittingSize: NSSize(width: 320, height: 18),
            visibleRect: visibleRect
        )

        XCTAssertGreaterThanOrEqual(frame.minX, visibleRect.minX)
        XCTAssertLessThanOrEqual(frame.maxX, visibleRect.maxX)
        XCTAssertEqual(frame.width, visibleRect.width - (SuggestionLabelLayout.edgePadding * 2), accuracy: 0.001)
    }

    func testSuggestionLabelClampsVerticallyInsideVisibleRect() {
        let visibleRect = NSRect(x: 0, y: 40, width: 200, height: 80)

        let frame = SuggestionLabelLayout.frame(
            anchorPoint: NSPoint(x: 8, y: 42),
            fittingSize: NSSize(width: 60, height: 18),
            visibleRect: visibleRect
        )

        XCTAssertGreaterThanOrEqual(frame.minY, visibleRect.minY)
        XCTAssertLessThanOrEqual(frame.maxY, visibleRect.maxY)
    }

    func testBuildsPrefixSuffixAndCurrentParagraphAroundCursor() {
        let text = """
        Intro line.
        Current paragraph starts here and keeps going.
        Final line.
        """
        let cursor = (text as NSString).range(of: " and keeps").location

        let request = SuggestionContextBuilder().request(
            documentText: text,
            selectedRange: NSRange(location: cursor, length: 0),
            maxSuggestionWords: 4
        )

        XCTAssertTrue(request.prefixContext.hasSuffix("Current paragraph starts here"))
        XCTAssertTrue(request.suffixContext.hasPrefix(" and keeps going."))
        XCTAssertEqual(request.currentParagraph, "Current paragraph starts here and keeps going.\n")
        XCTAssertEqual(request.cursorLocation, cursor)
        XCTAssertEqual(request.maxWords, 4)
    }

    func testClampsCursorAndSuggestionWordLimit() {
        let text = "Short text"

        let request = SuggestionContextBuilder().request(
            documentText: text,
            selectedRange: NSRange(location: 10_000, length: 0),
            maxSuggestionWords: 50
        )

        XCTAssertEqual(request.cursorLocation, (text as NSString).length)
        XCTAssertEqual(request.prefixContext, text)
        XCTAssertEqual(request.suffixContext, "")
        XCTAssertEqual(request.maxWords, 5)
    }

    func testKeepsCursorMarkerWhenThereIsTrailingContext() {
        let request = SuggestionContextBuilder().request(
            documentText: "Before cursor after cursor",
            selectedRange: NSRange(location: 6, length: 0),
            maxSuggestionWords: 3
        )

        XCTAssertTrue(request.documentContext.contains("[CURSOR]"))
        XCTAssertTrue(request.documentContext.hasPrefix("Before"))
        XCTAssertTrue(request.documentContext.hasSuffix(" cursor after cursor"))
    }

    func testOmitsCursorMarkerWhenTrailingContextIsWhitespaceOnly() {
        let request = SuggestionContextBuilder().request(
            documentText: "Done writing   \n",
            selectedRange: NSRange(location: 12, length: 0),
            maxSuggestionWords: 1
        )

        XCTAssertFalse(request.documentContext.contains("[CURSOR]"))
        XCTAssertEqual(request.maxWords, 2)
    }

    func testLimitsContextWindows() {
        var builder = SuggestionContextBuilder()
        builder.maxPrefixCharacters = 5
        builder.maxSuffixCharacters = 4
        builder.maxDocumentLeadingCharacters = 7
        builder.maxDocumentTrailingCharacters = 6

        let request = builder.request(
            documentText: "0123456789abcdef",
            selectedRange: NSRange(location: 10, length: 0),
            maxSuggestionWords: 4
        )

        XCTAssertEqual(request.prefixContext, "56789")
        XCTAssertEqual(request.suffixContext, "abcd")
        XCTAssertTrue(request.documentContext.hasPrefix("3456789"))
        XCTAssertTrue(request.documentContext.hasSuffix("abcdef"))
    }
}
