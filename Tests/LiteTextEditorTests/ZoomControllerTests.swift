import AppKit
import XCTest
@testable import LiteTextEditor

final class ZoomControllerTests: XCTestCase {
    func testSetZoomMagnificationClampsDisplayAndScrollViewMagnification() {
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

    private struct ControllerFixture {
        let window: NSWindow
        let controller: EditorController
        let scrollView: NSScrollView
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
