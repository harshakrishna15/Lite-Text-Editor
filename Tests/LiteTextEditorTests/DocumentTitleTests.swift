import XCTest
import SwiftUI
@testable import LiteTextEditor

final class DocumentTitleTests: XCTestCase {
    func testUnsavedDocumentTitleCommitTrimsWhitespaceAndReplacesPathSeparators() {
        let controller = EditorController()

        controller.commitDocumentTitle("  Project/Notes:Draft  ")

        XCTAssertEqual(controller.documentTitle, "Project-Notes-Draft")
        XCTAssertEqual(controller.documentStatusText, "Title updated")
    }

    func testBlankUnsavedDocumentTitleFallsBackToUntitled() {
        let controller = EditorController()
        controller.documentTitle = "Draft"

        controller.commitDocumentTitle("   ")

        XCTAssertEqual(controller.documentTitle, "Untitled")
        XCTAssertEqual(controller.documentStatusText, "Title updated")
    }

    func testUnchangedUnsavedDocumentTitleDoesNotChangeStatus() {
        let controller = EditorController()
        controller.documentTitle = "Draft"
        controller.documentStatusText = "Ready"

        controller.commitDocumentTitle("Draft")

        XCTAssertEqual(controller.documentTitle, "Draft")
        XCTAssertEqual(controller.documentStatusText, "Ready")
    }

    func testTitlebarStateStartsWithCurrentDocumentTitle() {
        let state = TitlebarDocumentTitleState(documentTitle: "Project Notes")

        XCTAssertEqual(state.draftTitle, "Project Notes")
        XCTAssertEqual(state.displayTitle, "Project Notes")
    }

    func testTitlebarStateDisplayTitleFallsBackToUntitled() {
        let state = TitlebarDocumentTitleState(documentTitle: "   ")

        XCTAssertEqual(state.displayTitle, "Untitled")
    }

    func testTitlebarStateSyncsExternalTitleChangesWhenNotFocused() {
        var state = TitlebarDocumentTitleState(documentTitle: "Untitled")

        state.syncDocumentTitle("Chapter One", isFocused: false)

        XCTAssertEqual(state.draftTitle, "Chapter One")
    }

    func testTitlebarStateDoesNotOverwriteActiveEditingDraft() {
        var state = TitlebarDocumentTitleState(documentTitle: "Draft")
        state.draftTitle = "Draft Renamed"

        state.syncDocumentTitle("External Title", isFocused: true)

        XCTAssertEqual(state.draftTitle, "Draft Renamed")
    }

    func testTitlebarTitleUsesLeadingAlignment() {
        XCTAssertEqual(TitlebarDocumentTitleLayout.textAlignment, .leading)
        XCTAssertGreaterThan(TitlebarDocumentTitleLayout.leadingGapAfterTrafficButtons, 0)
        XCTAssertGreaterThanOrEqual(TitlebarDocumentTitleLayout.minimumWidth, 120)
    }
}
