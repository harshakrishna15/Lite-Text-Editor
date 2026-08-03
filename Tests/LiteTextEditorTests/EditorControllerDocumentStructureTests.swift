import AppKit
import XCTest
@testable import LiteTextEditor

final class EditorControllerDocumentStructureTests: XCTestCase {
    func testCurrentOutlineHeadingTextUsesActiveHeadingAndReadableFallbacks() {
        let controller = EditorController()

        XCTAssertNil(controller.currentOutlineHeadingText)

        let heading = DocumentOutlineItem(
            title: "Overview",
            level: 1,
            location: 12,
            headingLength: 8,
            sectionNumber: "1",
            wordCount: 4,
            characterCount: 24,
            paragraphCount: 1,
            childCount: 0
        )
        controller.outlineItems = [heading]

        XCTAssertNil(controller.currentOutlineHeadingText)

        controller.activeOutlineItemID = heading.id

        XCTAssertEqual(controller.currentOutlineHeadingText, "1 Overview")

        controller.outlineItems = []

        XCTAssertNil(controller.currentOutlineHeadingText)
    }

    func testCurrentOutlineHeadingFollowsCaretAcrossSections() throws {
        let document = NSMutableAttributedString(
            string: "Intro.\nFirst Section\nFirst body.\nSecond Section\nSecond body.",
            attributes: EditorTypography.defaultTypingAttributes
        )
        applyHeadingStyle(to: "First Section", in: document)
        applyHeadingStyle(to: "Second Section", in: document)

        let textView = makeTextView(with: document)
        let controller = EditorController()
        controller.textView = textView
        controller.refreshOutlineItems()

        XCTAssertEqual(controller.outlineItems.map(\.displayTitle), ["1 First Section", "2 Second Section"])

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        controller.refreshActiveOutlineItem()
        XCTAssertNil(controller.currentOutlineHeadingText)

        let firstBodyRange = (document.string as NSString).range(of: "First body.")
        textView.setSelectedRange(NSRange(location: firstBodyRange.location, length: 0))
        controller.refreshActiveOutlineItem()
        XCTAssertEqual(controller.currentOutlineHeadingText, "1 First Section")

        let secondBodyRange = (document.string as NSString).range(of: "Second body.")
        textView.setSelectedRange(NSRange(location: secondBodyRange.location, length: 0))
        controller.refreshActiveOutlineItem()
        XCTAssertEqual(controller.currentOutlineHeadingText, "2 Second Section")
    }

    func testSwitchingTabsRefreshesAndRestoresCurrentOutlineHeading() throws {
        let headedContents = NSMutableAttributedString(
            string: "Chapter One\nChapter body.",
            attributes: EditorTypography.defaultTypingAttributes
        )
        applyHeadingStyle(to: "Chapter One", in: headedContents)
        let blankContents = NSAttributedString(
            string: "Loose notes without a heading.",
            attributes: EditorTypography.defaultTypingAttributes
        )
        let headedTabID = UUID()
        let blankTabID = UUID()
        let controller = EditorController()
        let textView = makeTextView(with: NSAttributedString(string: ""))
        controller.textView = textView
        controller.installDocument(
            EditorDocument(
                tabs: [
                    EditorDocumentTab(
                        id: headedTabID,
                        title: "Chapter",
                        attributedString: headedContents
                    ),
                    EditorDocumentTab(
                        id: blankTabID,
                        title: "Notes",
                        attributedString: blankContents
                    )
                ],
                selectedTabID: headedTabID
            )
        )

        let bodyRange = (headedContents.string as NSString).range(of: "Chapter body.")
        textView.setSelectedRange(NSRange(location: bodyRange.location, length: 0))
        controller.refreshActiveOutlineItem()
        XCTAssertEqual(controller.currentOutlineHeadingText, "1 Chapter One")

        controller.selectDocumentTab(blankTabID)
        XCTAssertNil(controller.currentOutlineHeadingText)

        controller.selectDocumentTab(headedTabID)
        XCTAssertEqual(controller.currentOutlineHeadingText, "1 Chapter One")
    }

    func testFloatingOutlineControlStaysCompactBesideExpandedPanel() {
        XCTAssertGreaterThanOrEqual(ChromeStyle.outlineCollapsedButtonHeight, 28)
        XCTAssertLessThanOrEqual(ChromeStyle.outlineCollapsedButtonHeight, 34)
        XCTAssertLessThanOrEqual(ChromeStyle.outlineCollapsedButtonWidth, 200)
        XCTAssertLessThan(ChromeStyle.outlineCollapsedButtonWidth, ChromeStyle.outlinePanelWidth)
        XCTAssertEqual(
            ChromeStyle.outlineCollapsedIconButtonWidth,
            ChromeStyle.outlineCollapsedButtonHeight
        )
    }

    private func applyHeadingStyle(to text: String, in document: NSMutableAttributedString) {
        let range = (document.string as NSString).range(of: text)
        XCTAssertNotEqual(range.location, NSNotFound)
        document.addAttribute(
            .font,
            value: EditorTypography.font(size: TextPreset.heading.size, weight: TextPreset.heading.weight),
            range: range
        )
    }

    private func makeTextView(with attributedString: NSAttributedString) -> AutocompleteTextView {
        let textStorage = NSTextStorage(attributedString: attributedString)
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
        textView.typingAttributes = EditorTypography.defaultTypingAttributes
        return textView
    }
}
