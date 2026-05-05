import AppKit
import XCTest
@testable import LiteTextEditor

final class PageLayoutTests: XCTestCase {
    func testPageCountUsesVisualPageGapAwareHeight() {
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: 0), 1)
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: AutocompleteTextView.pageContentHeight), 1)
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: AutocompleteTextView.pageContentHeight + 1), 2)
    }

    func testVisualContentConversionAccountsForPageGapAfterFirstPage() {
        let secondPageContentY = AutocompleteTextView.pageContentHeight + 24
        let expectedVisualY = AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap + 24

        XCTAssertEqual(AutocompleteTextView.visualContentY(forContentY: secondPageContentY), expectedVisualY)
        XCTAssertEqual(AutocompleteTextView.contentY(fromPotentialVisualY: expectedVisualY), secondPageContentY)
    }

    func testTallLineNearPageBottomMovesToNextPage() {
        let nearBottom = AutocompleteTextView.pageContentHeight - 4

        XCTAssertEqual(
            AutocompleteTextView.visualLineOriginY(forContentY: nearBottom, usedHeight: 20),
            AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap
        )
        XCTAssertEqual(
            AutocompleteTextView.visualLineOriginY(forContentY: nearBottom - 20, usedHeight: 10),
            nearBottom - 20
        )
    }

    func testPageStackHeightIncludesGapsBetweenPagesOnly() {
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 0), AutocompleteTextView.pageHeight)
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 1), AutocompleteTextView.pageHeight)
        XCTAssertEqual(
            AutocompleteTextView.pageStackHeight(forPageCount: 3),
            (AutocompleteTextView.pageHeight * 3) + (AutocompleteTextView.pageGap * 2)
        )
    }

    func testFitPageMagnificationRespectsMinimumZoom() {
        let tinyViewport = NSSize(width: 120, height: 120)
        let magnification = ZoomViewportCalculator.fitPageMagnification(
            contentSize: tinyViewport,
            minimumZoom: 0.5
        )

        XCTAssertEqual(magnification, 0.5)
    }

    func testFitPageMagnificationUsesMostConstrainedAxis() {
        let contentSize = NSSize(width: 900, height: 600)
        let magnification = ZoomViewportCalculator.fitPageMagnification(
            contentSize: contentSize,
            minimumZoom: 0.5
        )
        let expectedHeightFit = (600 - (AutocompleteTextView.deskPadding * 2)) / AutocompleteTextView.pageHeight

        XCTAssertEqual(magnification, expectedHeightFit, accuracy: 0.0001)
    }

    func testStableCenterPreservesVisibleCenterWhenViewportIsSmallerThanPage() {
        let pageFrame = NSRect(x: 100, y: 50, width: 612, height: 792)
        let visibleRect = NSRect(x: 0, y: 0, width: 320, height: 240)
        let center = ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)

        XCTAssertEqual(center.x, visibleRect.midX)
        XCTAssertEqual(center.y, visibleRect.midY)
    }

    func testStableCenterUsesPageCenterWhenViewportIsLargerThanPage() {
        let pageFrame = NSRect(x: 100, y: 50, width: 612, height: 792)
        let visibleRect = NSRect(x: 0, y: 0, width: 900, height: 1_000)
        let center = ZoomViewportCalculator.stableCenter(for: visibleRect, pageFrame: pageFrame)

        XCTAssertEqual(center.x, pageFrame.midX)
        XCTAssertEqual(center.y, pageFrame.midY)
    }

    func testClampedVisibleOriginNeverLeavesDocumentBounds() {
        let documentBounds = NSRect(x: 0, y: 0, width: 800, height: 1_000)
        let visibleSize = NSSize(width: 300, height: 300)

        XCTAssertEqual(
            ZoomViewportCalculator.clampedVisibleOrigin(
                centeredAt: NSPoint(x: -200, y: -200),
                visibleSize: visibleSize,
                documentBounds: documentBounds
            ),
            .zero
        )
        XCTAssertEqual(
            ZoomViewportCalculator.clampedVisibleOrigin(
                centeredAt: NSPoint(x: 1_200, y: 1_200),
                visibleSize: visibleSize,
                documentBounds: documentBounds
            ),
            NSPoint(x: 500, y: 700)
        )
    }

    func testTypingAtZoomExtremesKeepsPageVisibleAndFrameStableWhenPageCountDoesNotChange() {
        for magnification in [0.5, 2.0] {
            let fixture = makeZoomFixture()
            fixture.scrollView.allowsMagnification = true
            fixture.scrollView.minMagnification = 0.5
            fixture.scrollView.maxMagnification = 2.0
            fixture.scrollView.magnification = magnification

            fixture.textView.resizeForCurrentPages()
            let pageCountBefore = fixture.textView.currentPageCount
            let frameBefore = fixture.textView.frame
            fixture.textView.setSelectedRange(NSRange(location: fixture.textView.string.count, length: 0))
            fixture.textView.insertText(" more", replacementRange: fixture.textView.selectedRange())

            XCTAssertEqual(fixture.textView.currentPageCount, pageCountBefore)
            XCTAssertEqual(fixture.textView.frame.width, frameBefore.width, accuracy: 1)
            XCTAssertEqual(fixture.textView.currentPageStackFrame.intersects(fixture.scrollView.contentView.documentVisibleRect), true)
        }
    }

    func testMovingToDocumentStartCentersPageHorizontally() {
        let fixture = makeZoomFixture()
        fixture.scrollView.allowsMagnification = false
        fixture.scrollView.magnification = 1
        fixture.textView.resizeForCachedPages(at: 1)
        fixture.textView.restoreVisibleOrigin(NSPoint(x: fixture.textView.bounds.maxX, y: 200))

        fixture.textView.moveInsertionPointToDocumentStartAndScrollToPageTop()

        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
        XCTAssertEqual(fixture.scrollView.contentView.documentVisibleRect.minY, 0, accuracy: 1)
    }

    func testRestoreVisibleOriginComparesPhysicalOriginAtZoomScale() {
        let fixture = makeZoomFixture()
        fixture.textView.resizeForCachedPages(at: 2)

        fixture.textView.restoreVisibleOrigin(NSPoint(x: 32, y: 48))

        XCTAssertEqual(fixture.scrollView.contentView.bounds.origin.x, 64, accuracy: 1)
        XCTAssertEqual(fixture.scrollView.contentView.bounds.origin.y, 96, accuracy: 1)
    }

    func testTextLayoutDimensionSupportsLongDocumentsBeyondOldCap() {
        XCTAssertGreaterThanOrEqual(
            AutocompleteTextView.textLayoutDimensionLimit,
            AutocompleteTextView.pageContentHeight * 1_000
        )
    }

    func testPageRefreshAfterTextChangeReplacesPendingMeasurementWork() {
        let fixture = makeZoomFixture()
        let textView = fixture.textView

        textView.contentGeneration = 1
        textView.schedulePageRefreshAfterTextChange()
        let firstWorkItem = textView.pendingPageRefreshWorkItem

        textView.contentGeneration = 2
        textView.schedulePageRefreshAfterTextChange()

        XCTAssertTrue(firstWorkItem?.isCancelled == true)
        XCTAssertNotNil(textView.pendingPageRefreshWorkItem)
        XCTAssertFalse(textView.pendingPageRefreshWorkItem?.isCancelled == true)

        textView.pendingPageRefreshWorkItem?.cancel()
        textView.pendingPageRefreshWorkItem = nil
    }

    func testCenteringAfterViewportResizeKeepsPageHorizontallyCentered() {
        let fixture = makeZoomFixture()
        fixture.scrollView.setFrameSize(NSSize(width: 700, height: 320))
        fixture.textView.resizeForCachedPages(at: 1)
        fixture.textView.restoreVisibleOrigin(NSPoint(x: fixture.textView.bounds.maxX, y: 0))

        fixture.scrollView.setFrameSize(NSSize(width: 1_000, height: 320))
        fixture.textView.resizeForCachedPages()
        fixture.textView.centerPageHorizontallyPreservingVerticalPosition()

        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
    }

    func testDocumentWidthMatchesViewportWhilePageFitsHorizontally() {
        XCTAssertEqual(
            AutocompleteTextView.documentWidth(forViewportWidth: AutocompleteTextView.paperWidth + 38),
            AutocompleteTextView.paperWidth + 38
        )
    }

    func testDocumentWidthExceedsViewportOnlyWhenPageNoLongerFitsHorizontally() {
        XCTAssertEqual(
            AutocompleteTextView.documentWidth(forViewportWidth: AutocompleteTextView.paperWidth - 12),
            AutocompleteTextView.paperWidth
        )
    }

    func testSinglePageLayoutLeavesChromeClearanceAroundPageStack() {
        let fixture = makeZoomFixture()

        fixture.textView.resizeForCurrentPages()

        let pageFrame = fixture.textView.currentPageStackFrame
        let topGap = pageFrame.minY
        let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

        XCTAssertEqual(topGap, AutocompleteTextView.pageTopPadding(for: fixture.textView.documentLayoutScale), accuracy: 1)
        XCTAssertEqual(bottomGap, AutocompleteTextView.pageBottomPadding(for: fixture.textView.documentLayoutScale), accuracy: 1)
    }

    func testMultiPageLayoutLeavesChromeClearanceAroundPageStack() {
        let fixture = makeZoomFixture()
        fixture.textView.renderedPageCount = 3

        fixture.textView.resizeForCachedPages()

        let pageFrame = fixture.textView.currentPageStackFrame
        let topGap = pageFrame.minY
        let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

        XCTAssertEqual(topGap, AutocompleteTextView.pageTopPadding(for: fixture.textView.documentLayoutScale), accuracy: 1)
        XCTAssertEqual(bottomGap, AutocompleteTextView.pageBottomPadding(for: fixture.textView.documentLayoutScale), accuracy: 1)
    }

    func testPageChromeClearanceStaysVisuallyStableAcrossZoomLevels() {
        let fixture = makeZoomFixture()

        for magnification in [0.5, 1.0, 2.0] {
            fixture.textView.resizeForCachedPages(at: magnification)

            let pageFrame = fixture.textView.currentPageStackFrame
            let topGap = pageFrame.minY
            let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

            XCTAssertEqual(topGap * magnification, AutocompleteTextView.pageTopVisiblePadding, accuracy: 1)
            XCTAssertEqual(bottomGap * magnification, AutocompleteTextView.pageBottomVisiblePadding, accuracy: 1)
        }
    }

    func testTypingAcrossPageBoundaryReportsOneDocumentMetricsChange() {
        let fixture = makeZoomFixture()
        fixture.textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: Array(repeating: "Line", count: 42).joined(separator: "\n"),
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor.black
                ]
            )
        )
        fixture.textView.contentGeneration &+= 1
        fixture.textView.invalidatePageMeasurementCache()
        fixture.textView.resizeForCurrentPages()

        var metricsChangeCount = 0
        fixture.textView.onDocumentMetricsChanged = {
            metricsChangeCount += 1
        }

        fixture.textView.setSelectedRange(NSRange(location: (fixture.textView.string as NSString).length, length: 0))
        fixture.textView.insertText("\n" + Array(repeating: "More", count: 20).joined(separator: "\n"), replacementRange: fixture.textView.selectedRange())

        XCTAssertEqual(metricsChangeCount, 1)
    }

    private struct ZoomFixture {
        let window: NSWindow
        let scrollView: NSScrollView
        let textView: AutocompleteTextView
    }

    private func makeZoomFixture() -> ZoomFixture {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: AutocompleteTextView.pageTextWidth,
                height: AutocompleteTextView.textLayoutDimensionLimit
            )
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let scrollView = PaperScrollView(
            frame: NSRect(x: 0, y: 0, width: 700, height: 900)
        )
        let textView = AutocompleteTextView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: AutocompleteTextView.paperWidth + (AutocompleteTextView.deskPadding * 2),
                height: AutocompleteTextView.pageHeight + (AutocompleteTextView.deskPadding * 2)
            ),
            textContainer: textContainer
        )
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "A short paragraph.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.black
                ]
            )
        )
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 900),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        window.makeFirstResponder(textView)

        return ZoomFixture(window: window, scrollView: scrollView, textView: textView)
    }
}
