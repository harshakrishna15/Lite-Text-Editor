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

    func testHorizontalOnlyWheelEventsAreIgnored() {
        XCTAssertTrue(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 12, deltaY: 0))
        XCTAssertTrue(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: -12, deltaY: 0.2))
    }

    func testVerticalWheelEventsStillScroll() {
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 0, deltaY: 12))
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 0.2, deltaY: -12))
        XCTAssertFalse(PaperScrollView.shouldIgnoreHorizontalOnlyWheel(deltaX: 8, deltaY: 3))
    }

    func testHorizontalPanningIsAvailableOnlyWhenPageIsWiderThanViewport() {
        XCTAssertTrue(PaperScrollView.shouldAllowHorizontalPanning(visibleDocumentWidth: 560))
        XCTAssertFalse(PaperScrollView.shouldAllowHorizontalPanning(visibleDocumentWidth: 700))
        XCTAssertFalse(PaperScrollView.shouldAllowHorizontalPanning(visibleDocumentWidth: 612))
    }

    func testNativeMagnificationIsConfiguredWithoutCustomZoomState() {
        let scrollView = PaperScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        XCTAssertTrue(scrollView.allowsMagnification)
        XCTAssertEqual(scrollView.minMagnification, 1)
        XCTAssertEqual(scrollView.maxMagnification, 2)
        XCTAssertEqual(scrollView.magnification, 1)
    }

    func testZoomCommandsStepAndResetNativeMagnification() {
        let scrollView = PaperScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 1_000))

        scrollView.zoomDocumentIn(nil)
        XCTAssertEqual(scrollView.magnification, 1.1, accuracy: 0.001)

        scrollView.zoomDocumentOut(nil)
        XCTAssertEqual(scrollView.magnification, 1, accuracy: 0.001)

        scrollView.zoomDocumentIn(nil)
        scrollView.resetDocumentZoom(nil)
        XCTAssertEqual(scrollView.magnification, 1, accuracy: 0.001)
    }

}
