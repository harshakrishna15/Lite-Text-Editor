import XCTest
@testable import LiteTextEditor

final class AutosavePolicyTests: XCTestCase {
    private let policy = AutosavePolicy()

    func testEditedUnsavedDocumentDoesNotScheduleAutosave() {
        let decision = policy.editedDocumentDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: false,
                isDocumentEdited: true
            )
        )

        XCTAssertEqual(decision.statusText, "Unsaved changes")
        XCTAssertFalse(decision.shouldScheduleAutosave)
    }

    func testEditedSavedDocumentSchedulesOnlyWhenAutosaveIsEnabled() {
        let enabledDecision = policy.editedDocumentDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: true,
                isDocumentEdited: true
            )
        )
        let disabledDecision = policy.editedDocumentDecision(
            for: AutosavePolicy.State(
                isEnabled: false,
                hasSavedDocumentURL: true,
                isDocumentEdited: true
            )
        )

        XCTAssertEqual(enabledDecision.statusText, "Edited")
        XCTAssertTrue(enabledDecision.shouldScheduleAutosave)
        XCTAssertEqual(disabledDecision.statusText, "Edited")
        XCTAssertFalse(disabledDecision.shouldScheduleAutosave)
    }

    func testDisablingAutosaveCancelsPendingWork() {
        let decision = policy.toggledAutosaveDecision(
            for: AutosavePolicy.State(
                isEnabled: false,
                hasSavedDocumentURL: true,
                isDocumentEdited: true
            )
        )

        XCTAssertTrue(decision.shouldCancelPendingAutosave)
        XCTAssertFalse(decision.shouldScheduleAutosave)
        XCTAssertEqual(decision.statusText, "Edited")
    }

    func testEnablingAutosaveSchedulesOnlyWhenDocumentIsSavedAndEdited() {
        let savedEditedDecision = policy.toggledAutosaveDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: true,
                isDocumentEdited: true
            )
        )
        let unsavedDecision = policy.toggledAutosaveDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: false,
                isDocumentEdited: true
            )
        )
        let cleanDecision = policy.toggledAutosaveDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: true,
                isDocumentEdited: false
            )
        )

        XCTAssertFalse(savedEditedDecision.shouldCancelPendingAutosave)
        XCTAssertTrue(savedEditedDecision.shouldScheduleAutosave)
        XCTAssertEqual(savedEditedDecision.statusText, "Edited")

        XCTAssertFalse(unsavedDecision.shouldScheduleAutosave)
        XCTAssertNil(unsavedDecision.statusText)

        XCTAssertFalse(cleanDecision.shouldScheduleAutosave)
        XCTAssertNil(cleanDecision.statusText)
    }

    func testRunDecisionWritesOnlyEnabledSavedEditedDocuments() {
        XCTAssertTrue(
            policy.runDecision(
                for: AutosavePolicy.State(
                    isEnabled: true,
                    hasSavedDocumentURL: true,
                    isDocumentEdited: true
                )
            )
            .shouldWriteDocument
        )

        XCTAssertFalse(
            policy.runDecision(
                for: AutosavePolicy.State(
                    isEnabled: false,
                    hasSavedDocumentURL: true,
                    isDocumentEdited: true
                )
            )
            .shouldWriteDocument
        )

        XCTAssertFalse(
            policy.runDecision(
                for: AutosavePolicy.State(
                    isEnabled: true,
                    hasSavedDocumentURL: true,
                    isDocumentEdited: false
                )
            )
            .shouldWriteDocument
        )
    }

    func testRunDecisionReportsUnsavedStatusWhenEditedDocumentHasNoURL() {
        let decision = policy.runDecision(
            for: AutosavePolicy.State(
                isEnabled: true,
                hasSavedDocumentURL: false,
                isDocumentEdited: true
            )
        )

        XCTAssertFalse(decision.shouldWriteDocument)
        XCTAssertEqual(decision.statusTextIfSkipped, "Unsaved changes")
    }
}
