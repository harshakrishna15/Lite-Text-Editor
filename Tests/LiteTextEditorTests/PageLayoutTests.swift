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

    func testLineNearPageBottomStaysOnCurrentPageUntilOriginReachesPageEnd() {
        let nearBottom = AutocompleteTextView.pageContentHeight - 4

        XCTAssertEqual(
            AutocompleteTextView.visualLineOriginY(forContentY: nearBottom, usedHeight: 20),
            nearBottom
        )
        XCTAssertEqual(
            AutocompleteTextView.visualLineOriginY(
                forContentY: AutocompleteTextView.pageContentHeight,
                usedHeight: 20
            ),
            AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap
        )
    }

    func testPageCountUsesLineOriginBoundaryForNewPages() {
        let oneLineBeforeEnd = AutocompleteTextView.pageContentHeight - 4
        let nextPageOrigin = AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap

        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualLineOriginY: oneLineBeforeEnd), 1)
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualLineOriginY: nextPageOrigin), 2)
    }

    func testPageStackHeightIncludesGapsBetweenPagesOnly() {
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 0), AutocompleteTextView.pageHeight)
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 1), AutocompleteTextView.pageHeight)
        XCTAssertEqual(
            AutocompleteTextView.pageStackHeight(forPageCount: 3),
            (AutocompleteTextView.pageHeight * 3) + (AutocompleteTextView.pageGap * 2)
        )
    }

    func testVisiblePageRangeReturnsOnlyDirtyPageInLongDocument() {
        let pageOriginY: CGFloat = 56
        let pageStride = AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap
        let dirtyPage = 500
        let dirtyRect = NSRect(
            x: 0,
            y: pageOriginY + (CGFloat(dirtyPage) * pageStride) + 120,
            width: 100,
            height: 24
        )

        XCTAssertEqual(
            AutocompleteTextView.visiblePageRange(
                for: dirtyRect,
                pageOriginY: pageOriginY,
                renderedPageCount: 1_000
            ),
            dirtyPage...dirtyPage
        )
    }

    func testVisiblePageRangeClampsToLastRenderedPage() {
        let pageOriginY: CGFloat = 56
        let pageStride = AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap
        let dirtyRect = NSRect(
            x: 0,
            y: pageOriginY + (2 * pageStride) + AutocompleteTextView.pageHeight - 10,
            width: 100,
            height: 2_000
        )

        XCTAssertEqual(
            AutocompleteTextView.visiblePageRange(
                for: dirtyRect,
                pageOriginY: pageOriginY,
                renderedPageCount: 3
            ),
            2...2
        )
    }

    func testVisiblePageRangeReturnsNilOutsideRenderedPages() {
        let pageOriginY: CGFloat = 56
        let pageCount = 3
        let shadowOutset = AutocompleteTextView.PageDrawingStyle.shadowOutset
            + abs(AutocompleteTextView.PageDrawingStyle.shadowYOffset)
        let beforePages = NSRect(
            x: 0,
            y: pageOriginY - shadowOutset - 20,
            width: 100,
            height: 4
        )
        let afterPages = NSRect(
            x: 0,
            y: pageOriginY + AutocompleteTextView.pageStackHeight(forPageCount: pageCount) + shadowOutset + 20,
            width: 100,
            height: 4
        )

        XCTAssertNil(
            AutocompleteTextView.visiblePageRange(
                for: beforePages,
                pageOriginY: pageOriginY,
                renderedPageCount: pageCount
            )
        )
        XCTAssertNil(
            AutocompleteTextView.visiblePageRange(
                for: afterPages,
                pageOriginY: pageOriginY,
                renderedPageCount: pageCount
            )
        )
    }

    func testPageChromeDrawRectIncludesShadowButStaysTight() {
        let pageRect = NSRect(x: 100, y: 56, width: AutocompleteTextView.paperWidth, height: AutocompleteTextView.pageHeight)
        let chromeRect = AutocompleteTextView.pageChromeDrawRect(for: pageRect)

        XCTAssertLessThan(chromeRect.minX, pageRect.minX)
        XCTAssertGreaterThan(chromeRect.maxX, pageRect.maxX)
        XCTAssertGreaterThan(chromeRect.maxY, pageRect.maxY)
        XCTAssertLessThanOrEqual(
            chromeRect.width - pageRect.width,
            (AutocompleteTextView.PageDrawingStyle.shadowOutset * 2) + 2
        )
    }

    func testPageDrawingUsesSingleBoundedSoftShadowPass() {
        XCTAssertEqual(AutocompleteTextView.PageDrawingStyle.blurredShadowPassCount, 1)
        XCTAssertLessThanOrEqual(AutocompleteTextView.PageDrawingStyle.shadowBlurRadius, 12)
        XCTAssertLessThanOrEqual(AutocompleteTextView.PageDrawingStyle.shadowOutset, 14)
        XCTAssertLessThanOrEqual(AutocompleteTextView.PageDrawingStyle.maximumShadowAlpha, 0.11)
    }

    func testPageShadowUsesSubtleOffsetDepth() {
        XCTAssertEqual(AutocompleteTextView.PageDrawingStyle.shadowXOffset, 0)
        XCTAssertGreaterThan(AutocompleteTextView.PageDrawingStyle.shadowYOffset, 0)
        XCTAssertLessThan(AutocompleteTextView.PageDrawingStyle.shadowAlpha, 0.12)
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
        fixture.textView.resizeForCachedPages()
        fixture.textView.restoreVisibleOrigin(NSPoint(x: fixture.textView.bounds.maxX, y: 200))

        fixture.textView.moveInsertionPointToDocumentStartAndScrollToPageTop()

        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.minY,
            fixture.textView.currentPageStackFrame.minY - AutocompleteTextView.pageTopVisiblePadding,
            accuracy: 1
        )
    }

    func testRestoreVisibleOriginUsesLogicalDocumentCoordinatesAtNativeZoomScale() {
        let fixture = makeZoomFixture()
        fixture.scrollView.allowsMagnification = true
        fixture.scrollView.minMagnification = 0.5
        fixture.scrollView.maxMagnification = 2
        fixture.scrollView.magnification = 2
        fixture.textView.resizeForCachedPages()

        fixture.textView.restoreVisibleOrigin(NSPoint(x: 32, y: 48))

        XCTAssertEqual(fixture.scrollView.contentView.bounds.origin.x, 32, accuracy: 1)
        XCTAssertEqual(fixture.scrollView.contentView.bounds.origin.y, 48, accuracy: 1)
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
        fixture.textView.resizeForCachedPages()
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

    func testSinglePageLayoutCentersPageInMinimumZoomCanvas() {
        let fixture = makeZoomFixture()

        fixture.textView.resizeForCurrentPages()

        let pageFrame = fixture.textView.currentPageStackFrame
        let topGap = pageFrame.minY
        let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

        XCTAssertEqual(topGap, bottomGap, accuracy: 1)
        XCTAssertGreaterThanOrEqual(topGap, AutocompleteTextView.pageTopVisiblePadding)
        XCTAssertGreaterThanOrEqual(
            fixture.textView.bounds.width,
            fixture.scrollView.contentSize.width / AutocompleteTextView.minimumStableCanvasMagnification
        )
        XCTAssertGreaterThanOrEqual(
            fixture.textView.bounds.height,
            fixture.scrollView.contentSize.height / AutocompleteTextView.minimumStableCanvasMagnification
        )
    }

    func testPageCountTransitionsKeepTextAlignedAndPreservePageRelativeAnchor() {
        for (newlineCount, expectedPageCount) in [(50, 2), (120, 3)] {
            let fixture = makeZoomFixture()
            fixture.textView.resizeForCurrentPages()

            let boundsBefore = fixture.textView.bounds
            let pageFrameBefore = fixture.textView.currentPageStackFrame
            let originalInset = fixture.textView.textContainerInset
            let initialVisibleSize = fixture.scrollView.contentView.documentVisibleRect.size
            let initialAnchor = NSPoint(x: pageFrameBefore.midX, y: pageFrameBefore.midY)
            fixture.textView.restoreVisibleOrigin(
                ZoomViewportCalculator.clampedVisibleOrigin(
                    centeredAt: initialAnchor,
                    visibleSize: initialVisibleSize,
                    documentBounds: fixture.textView.bounds
                )
            )

            let visibleRectBefore = fixture.scrollView.contentView.documentVisibleRect
            let stableAnchorBefore = ZoomViewportCalculator.stableCenter(
                for: visibleRectBefore,
                pageFrame: pageFrameBefore
            )
            let pageRelativeAnchor = NSPoint(
                x: stableAnchorBefore.x - pageFrameBefore.minX,
                y: stableAnchorBefore.y - pageFrameBefore.minY
            )

            setFixedLineHeightText(
                String(repeating: "\n", count: newlineCount),
                lineHeight: 13,
                in: fixture.textView
            )
            fixture.textView.resizeForCurrentPages()

            XCTAssertEqual(fixture.textView.currentPageCount, expectedPageCount)
            let pageFrameAfter = fixture.textView.currentPageStackFrame
            XCTAssertEqual(
                fixture.textView.textContainerInset.height,
                pageFrameAfter.minY + AutocompleteTextView.pageMargin,
                accuracy: 1
            )
            XCTAssertNotEqual(fixture.textView.textContainerInset.height, originalInset.height, accuracy: 1)

            let mappedAnchor = NSPoint(
                x: pageFrameAfter.minX + pageRelativeAnchor.x,
                y: pageFrameAfter.minY + pageRelativeAnchor.y
            )
            let expectedOrigin = ZoomViewportCalculator.clampedVisibleOrigin(
                centeredAt: mappedAnchor,
                visibleSize: visibleRectBefore.size,
                documentBounds: fixture.textView.bounds
            )
            let visibleOriginAfter = fixture.scrollView.contentView.documentVisibleRect.origin
            XCTAssertEqual(visibleOriginAfter.x, expectedOrigin.x, accuracy: 1)
            XCTAssertEqual(visibleOriginAfter.y, expectedOrigin.y, accuracy: 1)

            if expectedPageCount == 2 {
                XCTAssertEqual(fixture.textView.bounds, boundsBefore)
            } else {
                XCTAssertGreaterThan(fixture.textView.bounds.height, boundsBefore.height)
            }
        }
    }

    func testShrinkingDocumentClampsOldPageAnchorIntoRemainingPage() {
        let fixture = makeZoomFixture()
        setFixedLineHeightText(
            String(repeating: "\n", count: 120),
            lineHeight: 13,
            in: fixture.textView
        )
        fixture.textView.resizeForCurrentPages()
        XCTAssertEqual(fixture.textView.currentPageCount, 3)

        let oldPageFrame = fixture.textView.currentPageStackFrame
        let lastPageCenter = NSPoint(
            x: oldPageFrame.midX,
            y: oldPageFrame.maxY - (AutocompleteTextView.pageHeight / 2)
        )
        fixture.textView.restoreVisibleOrigin(
            ZoomViewportCalculator.clampedVisibleOrigin(
                centeredAt: lastPageCenter,
                visibleSize: fixture.scrollView.contentView.documentVisibleRect.size,
                documentBounds: fixture.textView.bounds
            )
        )

        setFixedLineHeightText("Short document", lineHeight: 13, in: fixture.textView)
        fixture.textView.resizeForCurrentPages()

        XCTAssertEqual(fixture.textView.currentPageCount, 1)
        let remainingPage = fixture.textView.currentPageStackFrame
        let visibleRect = fixture.scrollView.contentView.documentVisibleRect
        XCTAssertTrue(remainingPage.intersects(visibleRect))
        XCTAssertEqual(visibleRect.midY, remainingPage.maxY, accuracy: 1)
        XCTAssertEqual(
            fixture.textView.textContainerInset.height,
            remainingPage.minY + AutocompleteTextView.pageMargin,
            accuracy: 1
        )
    }

    func testMultiPageLayoutLeavesChromeClearanceAroundPageStack() {
        let fixture = makeZoomFixture()
        fixture.textView.renderedPageCount = 3

        fixture.textView.resizeForCachedPages()

        let pageFrame = fixture.textView.currentPageStackFrame
        let topGap = pageFrame.minY
        let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

        XCTAssertEqual(topGap, AutocompleteTextView.pageTopVisiblePadding, accuracy: 1)
        XCTAssertEqual(bottomGap, AutocompleteTextView.pageBottomVisiblePadding, accuracy: 1)
    }

    func testNativeZoomKeepsDocumentFrameAndLogicalPageClearanceStable() {
        let fixture = makeZoomFixture()
        fixture.scrollView.allowsMagnification = true
        fixture.scrollView.minMagnification = 0.5
        fixture.scrollView.maxMagnification = 2
        fixture.textView.resizeForCachedPages()
        let frameBeforeZoom = fixture.textView.frame
        let boundsBeforeZoom = fixture.textView.bounds

        for magnification in [0.5, 1.0, 2.0] {
            fixture.scrollView.magnification = magnification

            let pageFrame = fixture.textView.currentPageStackFrame
            let topGap = pageFrame.minY
            let bottomGap = fixture.textView.bounds.height - pageFrame.maxY

            XCTAssertEqual(topGap, bottomGap, accuracy: 1)
            XCTAssertGreaterThanOrEqual(topGap, AutocompleteTextView.pageTopVisiblePadding)
            XCTAssertEqual(fixture.textView.frame, frameBeforeZoom)
            XCTAssertEqual(fixture.textView.bounds, boundsBeforeZoom)
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

    func testTrailingNewlineCreatesPageOnlyWhenBlankLineOriginReachesPageEnd() {
        let fixture = makeZoomFixture()
        let lineHeight: CGFloat = 13
        let newlineCountBeforeBoundary = Int(floor((AutocompleteTextView.pageContentHeight - 0.01) / lineHeight))

        setFixedLineHeightText(
            String(repeating: "\n", count: newlineCountBeforeBoundary),
            lineHeight: lineHeight,
            in: fixture.textView
        )
        fixture.textView.resizeForCurrentPages()

        XCTAssertEqual(fixture.textView.currentPageCount, 1)

        setFixedLineHeightText(
            String(repeating: "\n", count: newlineCountBeforeBoundary + 1),
            lineHeight: lineHeight,
            in: fixture.textView
        )
        fixture.textView.resizeForCurrentPages()

        XCTAssertEqual(fixture.textView.currentPageCount, 2)
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

    private func setFixedLineHeightText(
        _ text: String,
        lineHeight: CGFloat,
        in textView: AutocompleteTextView
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        textView.typingAttributes = attributes
        textView.contentGeneration &+= 1
        textView.invalidatePageMeasurementCache()
    }
}
