import AppKit
import XCTest
@testable import LiteTextEditor

final class FormattingOptionsCommandTests: XCTestCase {
    func testHighValueTextOptionsApplyExpectedAttributesAndTextChanges() {
        let fixture = makeFixture("hello world")
        let controller = fixture.controller
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        controller.toggleStrikethrough()
        XCTAssertNotNil(attribute(.strikethroughStyle, at: 0, in: textView))

        controller.setBaseline(.superscript)
        XCTAssertEqual(attribute(.superscript, at: 0, in: textView) as? Int, 1)

        controller.setBaseline(.subscript)
        XCTAssertEqual(attribute(.superscript, at: 0, in: textView) as? Int, -1)

        controller.setBaseline(.normal)
        XCTAssertNil(attribute(.superscript, at: 0, in: textView))

        controller.applyHighlight(.blue)
        XCTAssertNotNil(attribute(.backgroundColor, at: 0, in: textView))

        controller.applyHighlight(.clear)
        XCTAssertNil(attribute(.backgroundColor, at: 0, in: textView))

        controller.applyTextColor(.red)
        XCTAssertNotNil(attribute(.foregroundColor, at: 0, in: textView))

        controller.clearTextColor()
        XCTAssertNil(attribute(.foregroundColor, at: 0, in: textView))

        controller.setCharacterSpacing(.wider)
        XCTAssertEqual(attribute(.kern, at: 0, in: textView) as? CGFloat, 1.0)

        controller.setCharacterSpacing(.normal)
        XCTAssertNil(attribute(.kern, at: 0, in: textView))

        controller.applyTextCasing(.uppercase)
        XCTAssertEqual(textView.string, "HELLO world")

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        controller.applyTextCasing(.lowercase)
        XCTAssertEqual(textView.string, "hello world")

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        controller.applyTextCasing(.capitalizeWords)
        XCTAssertEqual(textView.string, "Hello world")

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        controller.applyTextCasing(.smallCaps)
        XCTAssertEqual(attribute(.liteTextEditorSmallCaps, at: 0, in: textView) as? Bool, true)
    }

    func testCopyAndPasteFormattingCopiesRepresentativeAttributes() {
        let fixture = makeFixture("source target")
        let controller = fixture.controller
        let textView = fixture.textView

        textView.setSelectedRange(NSRange(location: 0, length: 6))
        controller.toggleBold()
        controller.applyHighlight(.green)
        controller.copyFormatting()

        textView.setSelectedRange(NSRange(location: 7, length: 6))
        controller.pasteFormatting()

        let targetFont = attribute(.font, at: 7, in: textView) as? NSFont
        XCTAssertTrue(targetFont?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        XCTAssertNotNil(attribute(.backgroundColor, at: 7, in: textView))
    }

    func testParagraphOptionsApplyExpectedParagraphAttributes() {
        let fixture = makeFixture("First paragraph\nSecond paragraph")
        let controller = fixture.controller
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        controller.setLineSpacing(.oneAndHalf)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).lineHeightMultiple, 1.5, accuracy: 0.001)

        controller.applyParagraphSpacing(.before)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).paragraphSpacingBefore, 8, accuracy: 0.001)

        controller.applyParagraphSpacing(.after)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).paragraphSpacing, 8, accuracy: 0.001)

        controller.applyParagraphSpacing(.remove)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).paragraphSpacingBefore, 0, accuracy: 0.001)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).paragraphSpacing, 0, accuracy: 0.001)

        controller.applyParagraphIndent(.firstLine)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).firstLineHeadIndent, 36, accuracy: 0.001)

        controller.applyParagraphIndent(.hanging)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).headIndent, 36, accuracy: 0.001)

        controller.applyParagraphIndent(.clear)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).firstLineHeadIndent, 0, accuracy: 0.001)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).headIndent, 0, accuracy: 0.001)

        controller.toggleKeepParagraphTogether()
        XCTAssertEqual(attribute(.liteTextEditorKeepParagraphTogether, at: 0, in: textView) as? Bool, true)

        controller.toggleKeepWithNext()
        XCTAssertEqual(attribute(.liteTextEditorKeepWithNext, at: 0, in: textView) as? Bool, true)
    }

    func testListOptionsApplyEveryListStyleAndNumberingAction() {
        let fixture = makeFixture("First\nSecond")
        let controller = fixture.controller
        let textView = fixture.textView
        let fullRange = NSRange(location: 0, length: textView.string.count)

        for option in ListStyleOption.allCases {
            textView.textStorage?.setAttributedString(NSAttributedString(string: "First\nSecond"))
            textView.setSelectedRange(fullRange)

            controller.applyListStyle(option)

            switch option {
            case .bullet:
                XCTAssertEqual(textView.string, "• First\n• Second")
            case .dash:
                XCTAssertEqual(textView.string, "- First\n- Second")
            case .numbered:
                XCTAssertEqual(textView.string, "1. First\n2. Second")
            case .lettered:
                XCTAssertEqual(textView.string, "A. First\nB. Second")
            case .roman:
                XCTAssertEqual(textView.string, "I. First\nII. Second")
            case .checklist:
                XCTAssertEqual(textView.string, "☐ First\n☐ Second")
            }
        }

        textView.textStorage?.setAttributedString(NSAttributedString(string: "3. First\n4. Second"))
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        controller.applyListNumberingAction(.restart)
        XCTAssertEqual(textView.string, "1. First\n2. Second")

        textView.textStorage?.setAttributedString(NSAttributedString(string: "1. Before\n2. Prior\nNext\nLast"))
        textView.setSelectedRange(NSRange(location: 19, length: 9))
        controller.applyListNumberingAction(.continue)
        XCTAssertEqual(textView.string, "1. Before\n2. Prior\n3. Next\n4. Last")

        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        controller.increaseListLevel()
        XCTAssertTrue(textView.string.hasPrefix("\t1. Before"))

        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
        controller.decreaseListLevel()
        XCTAssertTrue(textView.string.hasPrefix("1. Before"))
    }

    func testListButtonsInsertVisibleMarkerOnEmptyDocument() {
        let expectedMarkers: [(ListStyleOption, String)] = [
            (.bullet, "• "),
            (.dash, "- "),
            (.numbered, "1. "),
            (.lettered, "A. "),
            (.roman, "I. "),
            (.checklist, "☐ ")
        ]

        for (option, marker) in expectedMarkers {
            let fixture = makeFixture("")
            fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))

            fixture.controller.applyListStyle(option)

            XCTAssertEqual(fixture.textView.string, marker)
            XCTAssertEqual(fixture.textView.selectedRange(), NSRange(location: marker.utf16.count, length: 0))
        }
    }

    func testBulletedToolbarCommandUsesBulletMarkerOnEmptyDocument() {
        let fixture = makeFixture("")
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))

        fixture.controller.togglePlainList()

        XCTAssertEqual(fixture.textView.string, "• ")
        XCTAssertEqual(fixture.textView.selectedRange(), NSRange(location: 2, length: 0))
    }

    func testReturnContinuesBulletListAndPreservesIndentation() {
        let fixture = makeFixture("\t• First")
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))

        textView.insertNewline(nil)

        XCTAssertEqual(textView.string, "\t• First\n\t• ")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: "\t• First\n\t• ".utf16.count, length: 0))
    }

    func testReturnContinuesNumberedListWithNextNumber() {
        let fixture = makeFixture("1. First")
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))

        textView.insertNewline(nil)

        XCTAssertEqual(textView.string, "1. First\n2. ")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: "1. First\n2. ".utf16.count, length: 0))
    }

    func testReturnOnEmptyListItemExitsList() {
        let fixture = makeFixture("• First\n• ")
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))

        textView.insertNewline(nil)

        XCTAssertEqual(textView.string, "• First\n")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: "• First\n".utf16.count, length: 0))
    }

    private struct Fixture {
        let controller: EditorController
        let textView: AutocompleteTextView
    }

    private func makeFixture(_ string: String) -> Fixture {
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

        let textView = AutocompleteTextView(frame: .zero, textContainer: textContainer)
        textView.allowsUndo = true
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .paragraphStyle: leftParagraphStyle()
        ]
        textView.typingAttributes = attributes
        textView.textStorage?.setAttributedString(NSAttributedString(string: string, attributes: attributes))

        let controller = EditorController()
        controller.textView = textView
        return Fixture(controller: controller, textView: textView)
    }

    private func attribute(_ key: NSAttributedString.Key, at location: Int, in textView: AutocompleteTextView) -> Any? {
        textView.textStorage?.attribute(key, at: location, effectiveRange: nil)
    }

    private func paragraphStyle(at location: Int, in textView: AutocompleteTextView) -> NSParagraphStyle {
        textView.textStorage?.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            ?? NSParagraphStyle.default
    }

    private func leftParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        return paragraphStyle
    }
}
