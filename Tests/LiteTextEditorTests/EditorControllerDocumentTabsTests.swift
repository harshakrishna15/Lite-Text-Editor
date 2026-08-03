import AppKit
import XCTest
@testable import LiteTextEditor

final class EditorControllerDocumentTabsTests: XCTestCase {
    func testAddingAndSwitchingTabsPreservesEachTabsContentsAndSelection() throws {
        let fixture = makeFixture()
        let controller = fixture.controller
        let textView = fixture.textView
        let tabOneID = try XCTUnwrap(controller.selectedDocumentTabID)

        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Tab 1 body",
                attributes: [.font: NSFont.systemFont(ofSize: 15)]
            )
        )
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Notes"])
        XCTAssertEqual(textView.string, "")
        XCTAssertTrue(controller.canCloseDocumentTab)

        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: "Notes body",
                attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .bold)]
            )
        )
        textView.setSelectedRange(NSRange(location: 10, length: 0))

        controller.selectDocumentTab(tabOneID)

        XCTAssertEqual(controller.selectedDocumentTabID, tabOneID)
        XCTAssertEqual(textView.string, "Tab 1 body")
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
        let tabOneID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.addDocumentTab(named: "Outline")
        let outlineID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.renameDocumentTab(outlineID, to: "  Notes\n ")
        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Notes", "Notes 2"])

        controller.selectDocumentTab(notesID)
        controller.closeDocumentTab(notesID)

        XCTAssertEqual(controller.documentTabs.map(\.id), [tabOneID, outlineID])
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
        XCTAssertEqual(selectedTab(in: controller)?.title, "Notes 2")

        controller.closeDocumentTab(tabOneID)
        XCTAssertEqual(controller.documentTabs.count, 1)
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
        XCTAssertFalse(controller.canCloseDocumentTab)

        controller.closeDocumentTab(outlineID)
        XCTAssertEqual(controller.documentTabs.count, 1)
        XCTAssertEqual(controller.selectedDocumentTabID, outlineID)
    }

    func testBlankDocumentStartsWithTabOneAndAddsSequentialTabs() {
        let controller = makeFixture().controller

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1"])
        XCTAssertEqual(selectedTab(in: controller)?.title, "Tab 1")
        XCTAssertFalse(controller.requiresNativeDocumentFormat)

        controller.addDocumentTab()
        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 2", "Tab 3"])
        XCTAssertEqual(selectedTab(in: controller)?.title, "Tab 3")
        XCTAssertTrue(controller.requiresNativeDocumentFormat)
    }

    func testAutomaticTabNamesContinueUpwardAfterClosingOrRenamingTabs() throws {
        let controller = makeFixture().controller

        controller.addDocumentTab()
        let tabTwoID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.addDocumentTab()
        controller.closeDocumentTab(tabTwoID)
        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 3", "Tab 4"])

        let tabFourID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.renameDocumentTab(tabFourID, to: "Notes")
        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 3", "Notes", "Tab 5"])
    }

    func testAutomaticTabNumberDoesNotMoveBackwardAfterClosingHighestTab() throws {
        let controller = makeFixture().controller

        controller.addDocumentTab()
        controller.addDocumentTab()
        let tabThreeID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.closeDocumentTab(tabThreeID)
        let snapshot = try XCTUnwrap(controller.editorDocumentSnapshot())
        controller.installDocument(snapshot.document)
        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 2", "Tab 4"])
    }

    func testClosingAnAutomaticTabKeepsItsNumberReservedForNativeSave() throws {
        let controller = makeFixture().controller

        controller.addDocumentTab()
        let tabTwoID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.closeDocumentTab(tabTwoID)

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1"])
        XCTAssertTrue(controller.requiresNativeDocumentFormat)

        controller.addDocumentTab()
        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 3"])
    }

    func testInstalledHighAutomaticNumberContinuesAscending() {
        let controller = makeFixture().controller
        let tabOneID = UUID()
        let tabSevenID = UUID()
        controller.installDocument(
            EditorDocument(
                tabs: [
                    EditorDocumentTab(
                        id: tabOneID,
                        title: "Tab 1",
                        attributedString: NSAttributedString(
                            string: "One",
                            attributes: EditorTypography.defaultTypingAttributes
                        )
                    ),
                    EditorDocumentTab(
                        id: tabSevenID,
                        title: "Tab 7",
                        attributedString: NSAttributedString(
                            string: "Seven",
                            attributes: EditorTypography.defaultTypingAttributes
                        )
                    )
                ],
                selectedTabID: tabSevenID
            )
        )

        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 7", "Tab 8"])
    }

    func testRenamingFirstTabContinuesWithTabTwoAndAllowsCapitalizationChanges() throws {
        let controller = makeFixture().controller
        let tabID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.renameDocumentTab(tabID, to: "notes")
        controller.renameDocumentTab(tabID, to: "Notes")
        XCTAssertEqual(selectedTab(in: controller)?.title, "Notes")
        XCTAssertTrue(controller.requiresNativeDocumentFormat)

        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Notes", "Tab 2"])
    }

    func testSuccessfulRenameUpdatesNonselectedTabAndMarksDocumentEdited() throws {
        let controller = makeFixture().controller
        let tabOneID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.addDocumentTab(named: "Notes")
        let notesID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.selectDocumentTab(tabOneID)
        controller.clearDocumentEdited()

        controller.renameDocumentTab(notesID, to: "Outline")

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Outline"])
        XCTAssertEqual(controller.selectedDocumentTabID, tabOneID)
        XCTAssertTrue(controller.isDocumentEdited)
    }

    func testAutomaticTabNamesAreReservedDuringRename() throws {
        let controller = makeFixture().controller
        let tabOneID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.addDocumentTab()
        let tabTwoID = try XCTUnwrap(controller.selectedDocumentTabID)
        controller.selectDocumentTab(tabOneID)
        controller.clearDocumentEdited()

        controller.renameDocumentTab(tabTwoID, to: "Tab 99")

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 2"])
        XCTAssertEqual(controller.selectedDocumentTabID, tabOneID)
        XCTAssertFalse(controller.isDocumentEdited)

        controller.addDocumentTab()
        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 2", "Tab 3"])
    }

    func testBlankRenameLeavesExistingTabNameUnchanged() throws {
        let controller = makeFixture().controller
        let tabID = try XCTUnwrap(controller.selectedDocumentTabID)

        controller.renameDocumentTab(tabID, to: "  \n  ")

        XCTAssertEqual(selectedTab(in: controller)?.title, "Tab 1")
        XCTAssertFalse(controller.requiresNativeDocumentFormat)
        XCTAssertFalse(controller.isDocumentEdited)
    }

    func testEachTabKeepsIndependentUndoHistory() throws {
        let fixture = makeFixture()
        let controller = fixture.controller
        let textView = fixture.textView
        let tabOneID = try XCTUnwrap(controller.selectedDocumentTabID)

        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Tab 1", attributes: EditorTypography.defaultTypingAttributes)
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

        controller.selectDocumentTab(tabOneID)
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

    private func selectedTab(in controller: EditorController) -> DocumentTabDescriptor? {
        guard let selectedID = controller.selectedDocumentTabID else { return nil }
        return controller.documentTabs.first { $0.id == selectedID }
    }
}
