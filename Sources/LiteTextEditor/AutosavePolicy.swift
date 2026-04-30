import Foundation

struct AutosavePolicy {
    struct State {
        let isEnabled: Bool
        let hasSavedDocumentURL: Bool
        let isDocumentEdited: Bool
    }

    struct EditDecision: Equatable {
        let statusText: String
        let shouldScheduleAutosave: Bool
    }

    struct ToggleDecision: Equatable {
        let shouldCancelPendingAutosave: Bool
        let shouldScheduleAutosave: Bool
        let statusText: String?
    }

    struct RunDecision: Equatable {
        let shouldWriteDocument: Bool
        let statusTextIfSkipped: String?
    }

    func editedDocumentDecision(for state: State) -> EditDecision {
        guard state.hasSavedDocumentURL else {
            return EditDecision(statusText: "Unsaved changes", shouldScheduleAutosave: false)
        }

        return EditDecision(statusText: "Edited", shouldScheduleAutosave: state.isEnabled)
    }

    func toggledAutosaveDecision(for state: State) -> ToggleDecision {
        if !state.isEnabled {
            return ToggleDecision(
                shouldCancelPendingAutosave: true,
                shouldScheduleAutosave: false,
                statusText: state.hasSavedDocumentURL && state.isDocumentEdited ? "Edited" : nil
            )
        }

        let shouldSchedule = state.hasSavedDocumentURL && state.isDocumentEdited
        return ToggleDecision(
            shouldCancelPendingAutosave: false,
            shouldScheduleAutosave: shouldSchedule,
            statusText: shouldSchedule ? "Edited" : nil
        )
    }

    func runDecision(for state: State) -> RunDecision {
        guard state.isEnabled else {
            return RunDecision(shouldWriteDocument: false, statusTextIfSkipped: nil)
        }

        guard state.isDocumentEdited else {
            return RunDecision(shouldWriteDocument: false, statusTextIfSkipped: nil)
        }

        guard state.hasSavedDocumentURL else {
            return RunDecision(shouldWriteDocument: false, statusTextIfSkipped: "Unsaved changes")
        }

        return RunDecision(shouldWriteDocument: true, statusTextIfSkipped: nil)
    }
}
