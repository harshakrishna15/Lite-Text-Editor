import AppKit
import XCTest
@testable import LiteTextEditor

final class PaperScrollViewTests: XCTestCase {
    func testScrollerRevealEdgeDetectionIncludesRightAndBottomEdges() {
        let bounds = NSRect(x: 0, y: 0, width: 800, height: 600)

        XCTAssertTrue(
            PaperScrollView.shouldRevealScrollers(
                for: NSPoint(x: 790, y: 300),
                in: bounds
            )
        )
        XCTAssertTrue(
            PaperScrollView.shouldRevealScrollers(
                for: NSPoint(x: 400, y: 10),
                in: bounds
            )
        )
    }

    func testScrollerRevealEdgeDetectionIgnoresInteriorAndOutsidePoints() {
        let bounds = NSRect(x: 0, y: 0, width: 800, height: 600)

        XCTAssertFalse(
            PaperScrollView.shouldRevealScrollers(
                for: NSPoint(x: 400, y: 300),
                in: bounds
            )
        )
        XCTAssertFalse(
            PaperScrollView.shouldRevealScrollers(
                for: NSPoint(x: 820, y: 300),
                in: bounds
            )
        )
    }

    func testClipViewRejectsHorizontalScrollUnlessProgrammatic() {
        let clipView = PaperClipView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        clipView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 1_000, height: 1_000))
        clipView.allowsProgrammaticHorizontalScroll = true
        clipView.setBoundsOrigin(NSPoint(x: 10, y: 20))
        clipView.allowsProgrammaticHorizontalScroll = false

        var constrainedBounds = clipView.constrainBoundsRect(NSRect(x: 80, y: 60, width: 400, height: 400))

        XCTAssertEqual(constrainedBounds.origin.x, 10)
        XCTAssertEqual(constrainedBounds.origin.y, 60)

        clipView.allowsProgrammaticHorizontalScroll = true
        constrainedBounds = clipView.constrainBoundsRect(NSRect(x: 80, y: 60, width: 400, height: 400))

        XCTAssertEqual(constrainedBounds.origin.x, 80)
    }

    func testClipViewRejectsDirectHorizontalBoundsOriginChanges() {
        let clipView = PaperClipView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        clipView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 1_000, height: 1_000))

        clipView.allowsProgrammaticHorizontalScroll = true
        clipView.setBoundsOrigin(NSPoint(x: 24, y: 30))
        clipView.allowsProgrammaticHorizontalScroll = false

        clipView.setBoundsOrigin(NSPoint(x: 120, y: 90))

        XCTAssertEqual(clipView.bounds.origin.x, 24)
        XCTAssertEqual(clipView.bounds.origin.y, 90)
    }

    func testClipViewRejectsDirectHorizontalScrollCalls() {
        let clipView = PaperClipView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        clipView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 1_000, height: 1_000))

        clipView.allowsProgrammaticHorizontalScroll = true
        clipView.scroll(to: NSPoint(x: 18, y: 30))
        clipView.allowsProgrammaticHorizontalScroll = false

        clipView.scroll(to: NSPoint(x: 140, y: 100))

        XCTAssertEqual(clipView.bounds.origin.x, 18)
        XCTAssertEqual(clipView.bounds.origin.y, 100)
    }

    func testHorizontalOnlyWheelEventsAreIgnored() {
        XCTAssertTrue(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 12, deltaY: 0))
        XCTAssertTrue(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: -12, deltaY: 0.2))
    }

    func testVerticalWheelEventsStillScroll() {
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 0, deltaY: 12))
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 0.2, deltaY: -12))
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 8, deltaY: 3))
    }
}
