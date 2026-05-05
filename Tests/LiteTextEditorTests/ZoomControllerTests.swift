import AppKit
import XCTest
@testable import LiteTextEditor

final class ZoomControllerTests: XCTestCase {
    func testSetZoomMagnificationClampsDisplayAndDocumentLayoutScale() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(4.0)

        XCTAssertEqual(fixture.controller.zoomMagnification, 2.0, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "200%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 2.0, accuracy: 0.001)

        fixture.controller.setZoomMagnification(0.1)

        XCTAssertEqual(fixture.controller.zoomMagnification, 0.5, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "50%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 0.5, accuracy: 0.001)
    }

    func testSetZoomMagnificationKeepsRequestedContinuousValue() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(0.93)

        XCTAssertEqual(fixture.controller.zoomMagnification, 0.93, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "93%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 0.93, accuracy: 0.001)

        fixture.controller.setZoomMagnification(1.31)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.31, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "131%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 1.31, accuracy: 0.001)
    }

    func testZoomingOutKeepsPageHorizontallyCentered() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(2.0)
        fixture.controller.setZoomMagnification(0.5)

        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
    }

    func testZoomingOutExpandsFrameToKeepPageCentered() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomMagnification(0.5)

        XCTAssertEqual(fixture.textView.frame.width, fixture.textView.bounds.width * 0.5, accuracy: 1)
        XCTAssertGreaterThanOrEqual(fixture.textView.bounds.width, fixture.scrollView.contentSize.width / 0.5)
        XCTAssertEqual(
            fixture.scrollView.contentView.documentVisibleRect.midX,
            fixture.textView.currentPageStackFrame.midX,
            accuracy: 1
        )
    }

    func testZoomRefreshesTextLayoutAndInsertionPointState() {
        let fixture = makeControllerFixture()
        let initialRefreshCount = fixture.textView.zoomLayoutRefreshCount

        fixture.controller.setZoomMagnification(1.4)

        XCTAssertGreaterThan(fixture.textView.zoomLayoutRefreshCount, initialRefreshCount)

        let refreshCountAfterCommittedZoom = fixture.textView.zoomLayoutRefreshCount

        fixture.controller.setZoomMagnification(1.2)

        XCTAssertGreaterThan(fixture.textView.zoomLayoutRefreshCount, refreshCountAfterCommittedZoom)
    }

    func testFitPageLayoutRefreshDoesNotForceTextLayoutRefresh() {
        let fixture = makeControllerFixture()

        fixture.controller.setZoomPreset(.fitPage)
        let refreshCountAfterPresetChange = fixture.textView.zoomLayoutRefreshCount

        fixture.controller.refreshZoomForLayout()

        XCTAssertEqual(fixture.textView.zoomLayoutRefreshCount, refreshCountAfterPresetChange)
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

    func testConfiguredScrollViewDisablesTrackpadMagnification() {
        let fixture = makeControllerFixture()

        XCTAssertFalse(fixture.scrollView.allowsMagnification)
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.minMagnification, 0.5, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.maxMagnification, 2.0, accuracy: 0.001)
        XCTAssertNotNil(fixture.scrollView.onMagnifyGesture)
    }

    func testTrackpadZoomUsesDocumentLayoutScaleWithoutScrollViewMagnification() {
        let fixture = makeControllerFixture()

        fixture.controller.applyTrackpadZoom(delta: 0.1, phase: .changed)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.1, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.zoomDisplayText, "110%")
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 1.1, accuracy: 0.001)

        fixture.controller.applyTrackpadZoom(delta: -0.1, phase: .changed)

        XCTAssertEqual(fixture.controller.zoomMagnification, 0.99, accuracy: 0.001)
        XCTAssertEqual(fixture.scrollView.magnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 0.99, accuracy: 0.001)
    }

    func testTrackpadZoomIgnoresEndedAndCancelledEvents() {
        let fixture = makeControllerFixture()

        fixture.controller.applyTrackpadZoom(delta: 0.2, phase: .ended)
        fixture.controller.applyTrackpadZoom(delta: 0.2, phase: .cancelled)

        XCTAssertEqual(fixture.controller.zoomMagnification, 1.0, accuracy: 0.001)
        XCTAssertEqual(fixture.textView.documentLayoutScale, 1.0, accuracy: 0.001)
    }

    func testReplacingScrollViewClearsOldTrackpadZoomHandler() {
        let fixture = makeControllerFixture()
        let replacementScrollView = PaperScrollView(frame: fixture.scrollView.frame)

        fixture.controller.scrollView = replacementScrollView

        XCTAssertNil(fixture.scrollView.onMagnifyGesture)
        XCTAssertNotNil(replacementScrollView.onMagnifyGesture)
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
}
