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

    func testStockScrollViewMagnificationPreservesVisibleAnchor() {
        let scrollView = PaperScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 1_200, height: 2_000))
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 2
        let anchor = NSPoint(x: 600, y: 800)
        scrollView.contentView.scroll(to: NSPoint(x: 400, y: 650))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        scrollView.setMagnification(2, centeredAt: anchor)

        XCTAssertEqual(scrollView.contentView.documentVisibleRect.midX, anchor.x, accuracy: 1)
        XCTAssertEqual(scrollView.contentView.documentVisibleRect.midY, anchor.y, accuracy: 1)
    }

    func testNativeMagnificationDoesNotPretendViewportSizeChanged() {
        let scrollView = PaperScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 1_200, height: 2_000))
        scrollView.allowsMagnification = true
        var viewportChangeCount = 0
        scrollView.onViewportSizeChanged = {
            viewportChangeCount += 1
        }

        scrollView.setMagnification(1.5, centeredAt: NSPoint(x: 200, y: 150))

        XCTAssertEqual(viewportChangeCount, 0)
    }
}
