import AppKit
import XCTest
@testable import LiteTextEditor

final class EditorControllerDocumentTabsTests: XCTestCase {
    func testAddingAndSwitchingTabsPreservesEachTabsContentsAndSelection() throws {
        let fixture = makeFixture()
        let controller = fixture.controller
        let textView = fixture.textView
        let draftID = try XCTUnwrap(controller.selectedDocumentTabID)

        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Draft body",
                attributes: [.font: NSFont.systemFont(ofSize: 15)]
            )
        )
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Draft", "Notes"])
        XCTAssertEqual(textView.string, "")
        XCTAssertTrue(controller.canCloseDocumentTab)

        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Notes body",
                attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .bold)]
            )
        )
        textView.setSelectedRange(NSRange(location: 10, length: 0))

        controller.selectDocumentTab(draftID)

        XCTAssertEqual(controller.selectedDocumentTabID, draftID)
        XCTAssertEqual(textView.string, "Draft body")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
        XCTAssertTrue(EditorTypography.isAllowedFont(try font(in: textView)))

        controller.selectDocumentTab(notesID)

        XCTAssertEqual(controller.selectedDocumentTabID, notesID)
        XCTAssertEqual(textView.string, "Notes body")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 10, length: 0))
        let notesFont = try font(in: textView)
        XCTAssertTrue(EditorTypography.isAllowedFont(notesFont))
        XCTAssertTrue(notesFont.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testRenameNormalizesAndUniquifiesTitlesAndCloseSelectsNeighbor() throws {
        let fixture = makeFixture()
        let controller = fixture.controller
        let draftID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.addDocumentTab(named: "Outline")
        let outlineID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.renameDocumentTab(outlineID, to: "  Draft\n ")
        XCTAssertEqual(controller.documentTabs.map(\.title), ["Draft", "Notes", "Draft 2"])

        controller.selectDocumentTab(notesID)
        controller.closeDocumentTab(notesID)

        XCTAssertEqual(controller.documentTabs.map(\.id), [draftID, outlineID])
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
        XCTAssertEqual(controller.selectedDocumentTab?.title, "Draft 2")

        controller.closeDocumentTab(draftID)
        XCTAssertEqual(controller.documentTabs.count, 1)
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
        XCTAssertFalse(controller.canCloseDocumentTab)

        controller.closeDocumentTab(outlineID)
        XCTAssertEqual(controller.documentTabs.count, 1)
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
    }

    func testEachTabKeepsIndependentUndoHistory() throws {
        let fixture = makeFixture()
        let controller = fixture.controller
        let textView = fixture.textView
        let draftID = try XCTUnwrap(controller.selectedDocumentTabID)

        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Draft", attributes: EditorTypography.defaultTypingAttributes)
        )
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        controller.toggleBold()
        XCTAssertTrue(try font(in: textView).fontDescriptor.symbolicTraits.contains(.bold))

        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Notes", attributes: EditorTypography.defaultTypingAttributes)
        )
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        controller.toggleItalic()
        XCTAssertTrue(try font(in: textView).fontDescriptor.symbolicTraits.contains(.italic))

        controller.selectDocumentTab(draftID)
        textView.undoManager?.undo()
        XCTAssertFalse(try font(in: textView).fontDescriptor.symbolicTraits.contains(.bold))

        controller.selectDocumentTab(notesID)
        XCTAssertTrue(try font(in: textView).fontDescriptor.symbolicTraits.contains(.italic))
        textView.undoManager?.undo()
        XCTAssertFalse(try font(in: textView).fontDescriptor.symbolicTraits.contains(.italic))
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
        textView.allowsUndo = true
        textView.typingAttributes = EditorTypography.defaultTypingAttributes

        let controller = EditorController()
        controller.textView = textView
        controller.installDocument(EditorDocument.blank())

        return Fixture(controller: controller, textView: textView)
    }

    private func font(in textView: AutocompleteTextView) throws -> NSFont {
        try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
    }
}
