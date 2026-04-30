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

    func testUnsavedDocumentLocationDefaultsToDownloads() {
        let controller = EditorController()

        XCTAssertEqual(controller.documentDirectoryURLForPanels.path, controller.defaultDocumentDirectoryURL.path)
        XCTAssertEqual(controller.defaultDocumentDirectoryURL.lastPathComponent, "Downloads")
        XCTAssertEqual(controller.documentLocationDisplayText, "Downloads")
    }

    func testUnsavedDocumentLocationUsesPendingDirectory() {
        let controller = EditorController()
        let directoryURL = URL(fileURLWithPath: "/Users/example/Documents")

        controller.updateDocumentDirectory(to: directoryURL)

        XCTAssertEqual(controller.pendingDocumentDirectoryURL?.path, directoryURL.standardizedFileURL.path)
        XCTAssertEqual(controller.documentLocationDisplayText, "Documents")
        XCTAssertEqual(controller.documentStatusText, "Location updated")
    }

    func testSavedDocumentLocationUsesCurrentDocumentDirectory() {
        let controller = EditorController()
        controller.currentDocumentURL = URL(fileURLWithPath: "/Users/example/Documents/Draft.rtf")

        XCTAssertEqual(controller.documentLocationDisplayText, "Documents")
    }

    func testMovingDocumentBuildsURLInSelectedDirectoryWithSameFilename() {
        let controller = EditorController()
        let currentURL = URL(fileURLWithPath: "/Users/example/Documents/Draft.rtf")
        let targetDirectoryURL = URL(fileURLWithPath: "/Users/example/Desktop")

        let movedURL = controller.documentURL(moving: currentURL, toDirectory: targetDirectoryURL)

        XCTAssertEqual(movedURL.path, "/Users/example/Desktop/Draft.rtf")
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

        state.syncDocumentTitle("Chapter One", isEditing: false)

        XCTAssertEqual(state.draftTitle, "Chapter One")
    }

    func testTitlebarStatePreparesDraftBeforePopoverEditing() {
        var state = TitlebarDocumentTitleState(documentTitle: "Draft")
        state.draftTitle = "Stale Draft"

        state.prepareForEditing(documentTitle: "Current Title")

        XCTAssertEqual(state.draftTitle, "Current Title")
    }

    func testTitlebarStateDoesNotOverwriteActivePopoverEditingDraft() {
        var state = TitlebarDocumentTitleState(documentTitle: "Draft")
        state.draftTitle = "Draft Renamed"

        state.syncDocumentTitle("External Title", isEditing: true)

        XCTAssertEqual(state.draftTitle, "Draft Renamed")
    }

    func testTitlebarTitleUsesLeadingAlignment() {
        XCTAssertEqual(TitlebarDocumentTitleLayout.textAlignment, .leading)
        XCTAssertGreaterThan(TitlebarDocumentTitleLayout.leadingGapAfterTrafficButtons, 0)
        XCTAssertGreaterThanOrEqual(TitlebarDocumentTitleLayout.minimumWidth, 120)
    }
}
