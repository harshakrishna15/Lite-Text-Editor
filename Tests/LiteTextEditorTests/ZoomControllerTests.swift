import AppKit
import XCTest
@testable import LiteTextEditor

final class ZoomControllerTests: XCTestCase {
    func testDefaultZoomUsesNativeScrollViewMagnification() {
        let fixture = makeControllerFixture()

        XCTAssertEqual(fixture.controller.selectedZoomPreset, .percent125)
        XCTAssertEqual(fixture.controller.zoomMagnification, 1.25, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "125%")
        XCTAssertTrue(fixture.scrollView.allowsMagnification)
        XCTAssertEqual(fixture.scrollView.magnification, 1.25, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.frame.size, fixture.textView.bounds.size)
    }

    func testSetZoomMagnificationClampsDisplayAndNativeMagnification() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(4.0)

        XCTAssertEqual(fixture.controller.zoomMagnification, 2.0, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "200%")
        XCTAssertEqual(fixture.scrollView.magnification, 2.0, accuracy: 0.001)

        fixture.controller.setZoomMagnification(0.1)

        XCTAssertEqual(fixture.controller.zoomMagnification, 0.5, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "50%")
        XCTAssertEqual(fixture.scrollView.magnification, 0.5, accuracy: 0.001)
    }

    func testSetZoomMagnificationKeepsRequestedContinuousValue() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(0.93)

        XCTAssertEqual(fixture.controller.zoomMagnification, 0.93, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "93%")
        XCTAssertEqual(fixture.scrollView.magnification, 0.93, accuracy: 0.001)

        fixture.controller.setZoomMagnification(1.31)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.31, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "131%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.31, accuracy: 0.001)
    }

    func testContinuousZoomDoesNotResizeOrRelayoutDocument() {
        let fixture = makeControllerFixture()
        let frameBeforeZoom = fixture.textView.frame
        let boundsBeforeZoom = fixture.textView.bounds
        let textContainerSizeBeforeZoom = fixture.textView.textContainer?.containerSize

        for step in 0...20 {
            fixture.controller.setZoomMagnification(0.75 + (Double(step) * 0.05))
        }

        XCTAssertEqual(fixture.textView.frame, frameBeforeZoom)
        XCTAssertEqual(fixture.textView.bounds, boundsBeforeZoom)
        XCTAssertEqual(fixture.textView.textContainer?.containerSize, textContainerSizeBeforeZoom)
        XCTAssertEqual(fixture.scrollView.magnification, 1.75, accuracy: 0.001)
    }

    func testZoomRoundTripPreservesAnchorOnMiddlePage() {
        let fixture = makeControllerFixture()
        fixture.textView.renderedPageCount = 12
        fixture.textView.resizeForCachedPages()

        let pageIndex = 5
        let pageRect = rectForPage(pageIndex, in: fixture.textView)
        let anchor = NSPoint(x: pageRect.midX, y: pageRect.midY)
        centerViewport(at: anchor, in: fixture)

        for magnification in [0.5, 2.0, 1.25] {
            fixture.controller.setZoomMagnification(magnification)

            let visibleRect = fixture.scrollView.contentView.documentVisibleRect
            XCTAssertEqual(visibleRect.midX, anchor.x, accuracy: 1)
            XCTAssertEqual(visibleRect.midY, anchor.y, accuracy: 1)
            XCTAssertTrue(pageRect.intersects(visibleRect))
        }
    }

    func testNativeZoomPreservesHorizontalAnchorWhenPageIsWiderThanViewport() {
        let fixture = makeControllerFixture()
        fixture.controller.setZoomMagnification(1.25)

        let anchor = NSPoint(
            x: fixture.textView.currentPageStackFrame.midX,
            y: fixture.scrollView.contentView.documentVisibleRect.midY
        )
        centerViewport(at: anchor, in: fixture)

        fixture.controller.setZoomMagnification(2.0)

        XCTAssertEqual(fixture.scrollView.contentView.documentVisibleRect.midX, anchor.x, accuracy: 1)
    }

    func testNativePinchOutRecentersPageAfterHighZoomHorizontalPan() {
        let fixture = makeControllerFixture()
        fixture.controller.setZoomMagnification(2.0)
        fixture.textView.restoreVisibleOrigin(
            NSPoint(x: fixture.textView.bounds.minX, y: fixture.scrollView.contentView.documentVisibleRect.minY)
        )
        let nativeGestureAnchor = fixture.scrollView.contentView.documentVisibleRect.center

        fixture.scrollView.setMagnification(1.0, centeredAt: nativeGestureAnchor)

        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
        XCTAssertEqual(fixture.controller.selectedZoomPreset, .actualSize)
    }

    func testObservingNativeMagnificationUpdatesStatusWithoutMovingViewport() {
        let fixture = makeControllerFixture()
        let anchor = fixture.textView.currentPageStackFrame.center
        centerViewport(at: anchor, in: fixture)

        fixture.scrollView.setMagnification(1.4, centeredAt: anchor)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.4, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "140%")
        XCTAssertEqual(fixture.controller.selectedZoomPreset, .custom)
        XCTAssertEqual(fixture.scrollView.magnification, 1.4, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.contentView.documentVisibleRect.midX, anchor.x, accuracy: 1)
        XCTAssertEqual(fixture.scrollView.contentView.documentVisibleRect.midY, anchor.y, accuracy: 1)
    }

    func testFitPageLayoutRefreshDoesNotResizeDocument() {
        let fixture = makeControllerFixture()
        let frameBeforeZoom = fixture.textView.frame
        let boundsBeforeZoom = fixture.textView.bounds

        fixture.controller.setZoomPreset(.fitPage)
        fixture.controller.refreshZoomForLayout()

        XCTAssertEqual(fixture.controller.selectedZoomPreset, .fitPage)
        XCTAssertEqual(fixture.textView.frame, frameBeforeZoom)
        XCTAssertEqual(fixture.textView.bounds, boundsBeforeZoom)
    }

    func testFitPageRemainsSelectedWhenNativeZoomClampsToMaximum() {
        let fixture = makeControllerFixture()
        fixture.scrollView.setFrameSize(NSSize(width: 2_000, height: 2_000))
        fixture.textView.resizeForCachedPages()

        fixture.controller.setZoomPreset(.fitPage)

        XCTAssertEqual(fixture.scrollView.magnification, 2.0, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.selectedZoomPreset, .fitPage)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "200%")
    }

    func testZoomPresetStepMovesThroughFixedPresets() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomPreset(.actualSize)
        fixture.controller.zoomIn()
        XCTAssertEqual(fixture.controller.selectedZoomPreset, .percent125)

        fixture.controller.zoomOut()
        XCTAssertEqual(fixture.controller.selectedZoomPreset, .actualSize)
    }

    func testZoomingKeepsPageStackVisible() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(2.0)
        XCTAssertTrue(fixture.textView.currentPageStackFrame.intersects(fixture.scrollView.contentView.documentVisibleRect))

        fixture.controller.setZoomMagnification(0.5)
        XCTAssertTrue(fixture.textView.currentPageStackFrame.intersects(fixture.scrollView.contentView.documentVisibleRect))
    }

    func testMinimumZoomCentersSinglePageInsteadOfClampingItToCanvasTop() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(2.0)
        fixture.controller.setZoomMagnification(0.5)

        let visibleRect = fixture.scrollView.contentView.documentVisibleRect
        let pageFrame = fixture.textView.currentPageStackFrame
        XCTAssertEqual(visibleRect.midX, pageFrame.midX, accuracy: 1)
        XCTAssertEqual(visibleRect.midY, pageFrame.midY, accuracy: 1)
        XCTAssertEqual(visibleRect.size, fixture.textView.bounds.size)
    }

    func testConfiguredScrollViewEnablesNativeTrackpadMagnification() {
        let fixture = makeControllerFixture()

        XCTAssertTrue(fixture.scrollView.allowsMagnification)
        XCTAssertEqual(fixture.scrollView.magnification, 1.25, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.minMagnification, 0.5, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.maxMagnification, 2.0, accuracy: 0.001)
        XCTAssertNotNil(fixture.controller.zoomMagnificationObservation)
        XCTAssertNotNil(fixture.controller.zoomClipBoundsObservation)
    }

    func testReplacingScrollViewMovesNativeMagnificationObservation() {
        let fixture = makeControllerFixture()
        let replacementScrollView = PaperScrollView(frame: fixture.scrollView.frame)
        replacementScrollView.documentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 1_400, height: 2_000)
        )

        fixture.controller.scrollView = replacementScrollView
        fixture.scrollView.setMagnification(1.8, centeredAt: .zero)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.25, accuracy: 0.001)

        replacementScrollView.setMagnification(1.4, centeredAt: .zero)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.4, accuracy: 0.001)
        XCTAssertNotNil(fixture.controller.zoomMagnificationObservation)
    }

    private struct ControllerFixture {
        let window: NSWindow
        let controller: EditorController
        let scrollView: PaperScrollView
        let textView: AutocompleteTextView
    }

    private func makeControllerFixture() -> ControllerFixture {
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

        let controller = EditorController()
        controller.textView = textView
        controller.scrollView = scrollView

        return ControllerFixture(
            window: window,
            controller: controller,
            scrollView: scrollView,
            textView: textView
        )
    }

    private func centerViewport(at anchor: NSPoint, in fixture: ControllerFixture) {
        let visibleSize = fixture.scrollView.contentView.documentVisibleRect.size
        let origin = ZoomViewportCalculator.clampedVisibleOrigin(
            centeredAt: anchor,
            visibleSize: visibleSize,
            documentBounds: fixture.textView.bounds
        )
        fixture.textView.restoreVisibleOrigin(origin)
    }

    private func rectForPage(_ index: Int, in textView: AutocompleteTextView) -> NSRect {
        let stackFrame = textView.currentPageStackFrame
        return NSRect(
            x: stackFrame.minX,
            y: stackFrame.minY + (CGFloat(index) * (AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap)),
            width: AutocompleteTextView.paperWidth,
            height: AutocompleteTextView.pageHeight
        )
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
