import XCTest
@testable import LiteTextEditor

final class SuggestionLabelLayoutTests: XCTestCase {
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

    func testSuggestionLabelRespectsMaximumPredictionWidth() {
        let visibleRect = NSRect(x: 0, y: 0, width: 500, height: 120)
        let frame = SuggestionLabelLayout.frame(
            anchorPoint: NSPoint(x: 100, y: 80),
            fittingSize: NSSize(width: 320, height: 42),
            visibleRect: visibleRect,
            maximumWidth: 140
        )

        XCTAssertEqual(frame.width, 140, accuracy: 0.001)
        XCTAssertLessThanOrEqual(frame.maxX, visibleRect.maxX)
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
}
