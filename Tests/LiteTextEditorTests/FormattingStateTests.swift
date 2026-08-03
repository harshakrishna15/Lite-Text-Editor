import AppKit
import XCTest
@testable import LiteTextEditor

final class FormattingStateTests: XCTestCase {
    func testEmptySelectionSamplesAttributesAtInsertionPoint() {
        let fixture = makeFixture()
        let font = NSFont(name: "Helvetica", size: 18) ?? NSFont.systemFont(ofSize: 18)
        fixture.textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Formatted text",
                attributes: [
                    .font: font,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        )
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 18, accuracy: 0.001)
        XCTAssertTrue(fixture.controller.formattingState.isUnderline)
    }

    func testMouseFormattingSampleOverridesEmptySelection() {
        let fixture = makeFixture()
        let firstFont = NSFont.systemFont(ofSize: 11)
        let sampledFont = NSFont(name: "Helvetica", size: 22) ?? NSFont.systemFont(ofSize: 22)
        let text = NSMutableAttributedString(
            string: "Plain Sampled",
            attributes: [.font: firstFont]
        )
        text.addAttributes(
            [.font: sampledFont],
            range: NSRange(location: 6, length: 7)
        )
        fixture.textView.textStorage?.setAttributedString(text)
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))
        fixture.textView.updateFormattingSampleLocation(6)

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 22, accuracy: 0.001)
    }

    func testNonEmptySelectionOverridesMouseFormattingSample() {
        let fixture = makeFixture()
        let selectedFont = NSFont.systemFont(ofSize: 16)
        let hoveredFont = NSFont.systemFont(ofSize: 24)
        let text = NSMutableAttributedString(
            string: "Selected Hovered",
            attributes: [.font: selectedFont]
        )
        text.addAttributes(
            [.font: hoveredFont],
            range: NSRange(location: 9, length: 7)
        )
        fixture.textView.textStorage?.setAttributedString(text)
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 8))
        fixture.textView.updateFormattingSampleLocation(9)

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 16, accuracy: 0.001)
    }

    func testApplyingFontSizeToSelectionPreservesFontTraits() throws {
        let fixture = makeFixture()
        let boldFont = EditorTypography.font(size: 12, weight: .bold)
        fixture.textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Selected text",
                attributes: [.font: boldFont]
            )
        )
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 13))

        fixture.controller.applyFontSize(24)

        let appliedFont = try XCTUnwrap(
            fixture.textView.textStorage?.attribute(
                .font,
                at: 0,
                effectiveRange: nil
            ) as? NSFont
        )
        XCTAssertEqual(appliedFont.pointSize, 24, accuracy: 0.001)
        XCTAssertTrue(appliedFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertEqual(fixture.controller.formattingState.fontSize, 24, accuracy: 0.001)
    }

    func testApplyingFontSizeAtInsertionPointUpdatesTypingFont() throws {
        let fixture = makeFixture()
        let baseFont = EditorTypography.font(size: 12)
        let italicFont = NSFont(
            descriptor: baseFont.fontDescriptor.withSymbolicTraits(.italic),
            size: 12
        ) ?? baseFont
        fixture.textView.typingAttributes[.font] = italicFont

        fixture.controller.applyFontSize(18)

        let typingFont = try XCTUnwrap(fixture.textView.typingAttributes[.font] as? NSFont)
        XCTAssertEqual(typingFont.pointSize, 18, accuracy: 0.001)
        XCTAssertTrue(typingFont.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertEqual(fixture.controller.formattingState.fontSize, 18, accuracy: 0.001)
    }

    private struct Fixture {
        let controller: EditorController
        let textView: AutocompleteTextView
    }

    private func makeFixture() -> Fixture {
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

        let textView = AutocompleteTextView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: AutocompleteTextView.paperWidth,
                height: AutocompleteTextView.pageHeight
            ),
            textContainer: textContainer
        )
        let controller = EditorController()
        controller.textView = textView

        return Fixture(controller: controller, textView: textView)
    }

}
