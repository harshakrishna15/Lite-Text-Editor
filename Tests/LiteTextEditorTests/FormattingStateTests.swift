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
                    .foregroundColor: NSColor.systemRed,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        )
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 18, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.formattingState.fontFamilyName, expectedFamilyName(for: font))
        XCTAssertTrue(fixture.controller.formattingState.isUnderline)
        XCTAssertTrue(fixture.controller.formattingState.isStrikethrough)
        XCTAssertTrue(fixture.controller.formattingState.textColor.isEqual(NSColor.systemRed))
    }

    func testMouseFormattingSampleOverridesEmptySelection() {
        let fixture = makeFixture()
        let firstFont = NSFont.systemFont(ofSize: 11)
        let sampledFont = NSFont(name: "Helvetica", size: 22) ?? NSFont.systemFont(ofSize: 22)
        let text = NSMutableAttributedString(
            string: "Plain Sampled",
            attributes: [
                .font: firstFont,
                .foregroundColor: NSColor.black
            ]
        )
        text.addAttributes(
            [
                .font: sampledFont,
                .foregroundColor: NSColor.systemBlue
            ],
            range: NSRange(location: 6, length: 7)
        )
        fixture.textView.textStorage?.setAttributedString(text)
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))
        fixture.textView.updateFormattingSampleLocation(6)

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 22, accuracy: 0.001)
        XCTAssertEqual(fixture.controller.formattingState.fontFamilyName, expectedFamilyName(for: sampledFont))
        XCTAssertTrue(fixture.controller.formattingState.textColor.isEqual(NSColor.systemBlue))
    }

    func testNonEmptySelectionOverridesMouseFormattingSample() {
        let fixture = makeFixture()
        let selectedFont = NSFont.systemFont(ofSize: 16)
        let hoveredFont = NSFont.systemFont(ofSize: 24)
        let text = NSMutableAttributedString(
            string: "Selected Hovered",
            attributes: [
                .font: selectedFont,
                .foregroundColor: NSColor.black
            ]
        )
        text.addAttributes(
            [
                .font: hoveredFont,
                .foregroundColor: NSColor.systemGreen
            ],
            range: NSRange(location: 9, length: 7)
        )
        fixture.textView.textStorage?.setAttributedString(text)
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 8))
        fixture.textView.updateFormattingSampleLocation(9)

        fixture.controller.refreshFormattingState()

        XCTAssertEqual(fixture.controller.formattingState.fontSize, 16, accuracy: 0.001)
        XCTAssertTrue(fixture.controller.formattingState.textColor.isEqual(NSColor.black))
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

    private func expectedFamilyName(for font: NSFont) -> String {
        SystemFontName.displayName(for: font)
    }
}
