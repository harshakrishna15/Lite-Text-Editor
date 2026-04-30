import AppKit
import UniformTypeIdentifiers

extension EditorController {
    func markDocumentEdited() {
        if !isDocumentEdited {
            isDocumentEdited = true
            textView?.window?.isDocumentEdited = true
        }

        let decision = autosavePolicy.editedDocumentDecision(for: currentAutosaveState)
        setDocumentStatus(decision.statusText)

        if decision.shouldScheduleAutosave {
            scheduleAutosave()
        } else {
            updateAutosaveStatusForCurrentState()
        }
    }

    func setAutosaveEnabled(_ isEnabled: Bool) {
        guard isAutosaveEnabled != isEnabled else { return }

        isAutosaveEnabled = isEnabled
        AutosaveSettingsStore.saveIsEnabled(isEnabled)

        let decision = autosavePolicy.toggledAutosaveDecision(for: currentAutosaveState)

        if decision.shouldCancelPendingAutosave {
            cancelPendingAutosave()
        }

        if let statusText = decision.statusText {
            setDocumentStatus(statusText)
        }

        if decision.shouldScheduleAutosave {
            scheduleAutosave()
        } else {
            updateAutosaveStatusForCurrentState()
        }
    }

    func clearDocumentEdited() {
        cancelPendingAutosave()

        isDocumentEdited = false
        textView?.window?.isDocumentEdited = false
        updateAutosaveStatusForCurrentState(cleanStatus: .clean)
    }

    func restoreLastSessionIfNeeded() {
        guard !hasRestoredLastSession, let textView else { return }
        hasRestoredLastSession = true

        do {
            if let url = AutosaveStore.lastDocumentURL, FileManager.default.fileExists(atPath: url.path) {
                try loadDocument(from: url, into: textView)
                currentDocumentURL = url
                AutosaveStore.saveLastDocumentURL(url)
                noteRecentDocument(url)
                clearDocumentEdited()
                setDocumentStatus("Opened last document")
                return
            }

            setDocumentStatus("Ready")
            updateAutosaveStatusForCurrentState()
        } catch {
            setDocumentStatus("Could not restore last document")
            updateAutosaveStatusForCurrentState()
        }
    }

    func flushAutosave() {
        cancelPendingAutosave()
        performAutosave()
    }

    func confirmQuit() -> NSApplication.TerminateReply {
        guard isDocumentEdited else {
            flushAutosave()
            return .terminateNow
        }

        return confirmUnsavedChanges(messageText: "Do you want to save changes before quitting?") ? .terminateNow : .terminateCancel
    }

    func newDocument() {
        guard confirmUnsavedChanges(messageText: "Do you want to save changes before creating a new document?") else { return }
        resetToBlankDocument()
        setDocumentStatus("New document")
    }

    func openDocument() {
        guard let textView else { return }
        guard confirmUnsavedChanges(messageText: "Do you want to save changes before opening another document?") else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.rtf, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try loadDocument(from: url, into: textView)
            currentDocumentURL = url
            AutosaveStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
            clearDocumentEdited()
            setDocumentStatus("Opened")
        } catch {
            showError(error, message: "The document could not be opened.")
        }
    }

    func openRecentDocument(_ url: URL) {
        guard let textView else { return }
        guard confirmUnsavedChanges(messageText: "Do you want to save changes before opening \(url.lastPathComponent)?") else { return }

        do {
            try loadDocument(from: url, into: textView)
            currentDocumentURL = url
            AutosaveStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
            clearDocumentEdited()
            setDocumentStatus("Opened")
        } catch {
            recentDocumentStore.remove(url)
            postRecentDocumentsChanged()
            showError(error, message: "The recent document could not be opened.")
        }
    }

    @discardableResult
    func saveDocument() -> Bool {
        guard let url = currentDocumentURL else {
            return saveDocumentAs()
        }

        do {
            try writeDocument(to: url)
            AutosaveStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
            updateWindowTitle(for: url)
            clearDocumentEdited(cleanStatus: .saved)
            setDocumentStatus("Saved")
            return true
        } catch {
            showError(error, message: "The document could not be saved.")
            setDocumentStatus("Save failed")
            autosaveStatus = .failed
            return false
        }
    }

    @discardableResult
    func saveDocumentAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rtf, .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = documentFileStore.suggestedDocumentName(
            currentDocumentURL: currentDocumentURL,
            fileExtension: "rtf"
        )

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }

        let url = documentFileStore.normalizedTextDocumentURL(selectedURL)

        do {
            try writeDocument(to: url)
            currentDocumentURL = url
            AutosaveStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
            updateWindowTitle(for: url)
            clearDocumentEdited(cleanStatus: .saved)
            setDocumentStatus("Saved")
            return true
        } catch {
            showError(error, message: "The document could not be saved.")
            setDocumentStatus("Save failed")
            autosaveStatus = .failed
            return false
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = documentFileStore.suggestedDocumentName(
            currentDocumentURL: currentDocumentURL,
            fileExtension: "pdf"
        )

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let url = documentFileStore.normalizedPDFURL(selectedURL)

        do {
            try writePDF(to: url)
            setDocumentStatus("Exported PDF")
        } catch {
            showError(error, message: "The PDF could not be exported.")
            setDocumentStatus("Export failed")
        }
    }

    private func scheduleAutosave() {
        guard autosavePolicy.editedDocumentDecision(for: currentAutosaveState).shouldScheduleAutosave else { return }
        cancelPendingAutosave()
        autosaveStatus = .pending

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingAutosaveWorkItem = nil
            self?.performAutosave()
        }

        pendingAutosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func performAutosave() {
        guard let textView else { return }

        let decision = autosavePolicy.runDecision(for: currentAutosaveState)
        guard decision.shouldWriteDocument else {
            if let statusText = decision.statusTextIfSkipped {
                setDocumentStatus(statusText)
            }
            updateAutosaveStatusForCurrentState()
            return
        }

        guard let url = currentDocumentURL else { return }

        do {
            autosaveStatus = .saving
            try writeDocument(to: url)
            AutosaveStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
            updateWindowTitle(for: url)
            isDocumentEdited = false
            textView.window?.isDocumentEdited = false
            autosaveStatus = .saved
            setDocumentStatus("Autosaved")
        } catch {
            autosaveStatus = .failed
            setDocumentStatus("Autosave failed")
        }
    }

    private var currentAutosaveState: AutosavePolicy.State {
        AutosavePolicy.State(
            isEnabled: isAutosaveEnabled,
            hasSavedDocumentURL: currentDocumentURL != nil,
            isDocumentEdited: isDocumentEdited
        )
    }

    private func cancelPendingAutosave() {
        pendingAutosaveWorkItem?.cancel()
        pendingAutosaveWorkItem = nil
    }

    private func clearDocumentEdited(cleanStatus: AutosaveStatus) {
        cancelPendingAutosave()
        isDocumentEdited = false
        textView?.window?.isDocumentEdited = false
        updateAutosaveStatusForCurrentState(cleanStatus: cleanStatus)
    }

    private func updateAutosaveStatusForCurrentState(cleanStatus: AutosaveStatus = .clean) {
        if !isAutosaveEnabled {
            autosaveStatus = .off
        } else if currentDocumentURL == nil {
            autosaveStatus = .unavailable
        } else if isDocumentEdited {
            autosaveStatus = .pending
        } else {
            autosaveStatus = cleanStatus
        }
    }

    private func setDocumentStatus(_ text: String) {
        if documentStatusText != text {
            documentStatusText = text
        }
    }

    private func confirmUnsavedChanges(messageText: String) -> Bool {
        guard isDocumentEdited else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = messageText
        alert.informativeText = "If you do not save, your changes will be lost."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveDocument()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func resetToBlankDocument() {
        guard let textView else { return }

        textView.textStorage?.setAttributedString(NSAttributedString(string: "", attributes: documentFileStore.defaultTypingAttributes))
        textView.contentGeneration &+= 1
        textView.invalidatePageMeasurementCache()
        textView.typingAttributes = documentFileStore.defaultTypingAttributes
        currentDocumentURL = nil
        textView.window?.title = "Untitled"
        textView.window?.representedURL = nil
        textView.resizeForCurrentPages()
        textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        textView.refreshSuggestion()
        textView.undoManager?.removeAllActions()
        refreshDocumentStatistics()
        refreshFormattingState()
        clearDocumentEdited()
    }

    private func loadDocument(from url: URL, into textView: AutocompleteTextView) throws {
        let attributedString = try documentFileStore.readDocument(from: url)

        textView.textStorage?.setAttributedString(attributedString)
        textView.contentGeneration &+= 1
        textView.invalidatePageMeasurementCache()
        textView.typingAttributes = documentFileStore.defaultTypingAttributes
        textView.resizeForCurrentPages()
        textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        textView.refreshSuggestion()
        textView.undoManager?.removeAllActions()
        updateWindowTitle(for: url)
        refreshDocumentStatistics()
        refreshFormattingState()
    }

    private func writeDocument(to url: URL) throws {
        guard let textStorage = textView?.textStorage else { return }
        try documentFileStore.writeDocument(NSAttributedString(attributedString: textStorage), to: url)
    }

    private func writePDF(to url: URL) throws {
        guard let textStorage = textView?.textStorage else { return }
        try documentFileStore.writePDF(NSAttributedString(attributedString: textStorage), to: url)
    }

    private func updateWindowTitle(for url: URL) {
        textView?.window?.title = url.lastPathComponent
        textView?.window?.representedURL = url
    }

    private func noteRecentDocument(_ url: URL) {
        recentDocumentStore.note(url)
        postRecentDocumentsChanged()
    }

    private func postRecentDocumentsChanged() {
        NotificationCenter.default.post(name: .liteTextEditorRecentDocumentsChanged, object: nil)
    }

    private func showError(_ error: Error, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
