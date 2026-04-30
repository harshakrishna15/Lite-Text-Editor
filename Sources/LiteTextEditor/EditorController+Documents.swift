import AppKit
import UniformTypeIdentifiers

extension EditorController {
    func markDocumentEdited() {
        if !isDocumentEdited {
            isDocumentEdited = true
            textView?.window?.isDocumentEdited = true
        }

        if currentDocumentURL == nil {
            setDocumentStatus("Unsaved changes")
        } else if isAutosaveEnabled {
            setDocumentStatus("Edited")
            scheduleAutosave()
        } else {
            setDocumentStatus("Edited")
        }
    }

    func setAutosaveEnabled(_ isEnabled: Bool) {
        guard isAutosaveEnabled != isEnabled else { return }

        isAutosaveEnabled = isEnabled
        AutosaveSettingsStore.saveIsEnabled(isEnabled)

        if isEnabled {
            guard currentDocumentURL != nil, isDocumentEdited else { return }
            setDocumentStatus("Edited")
            scheduleAutosave()
        } else {
            pendingAutosaveWorkItem?.cancel()
            pendingAutosaveWorkItem = nil
            guard currentDocumentURL != nil, isDocumentEdited else { return }
            setDocumentStatus("Edited")
        }
    }

    func clearDocumentEdited() {
        pendingAutosaveWorkItem?.cancel()
        pendingAutosaveWorkItem = nil

        guard isDocumentEdited || textView?.window?.isDocumentEdited == true else { return }
        isDocumentEdited = false
        textView?.window?.isDocumentEdited = false
    }

    func restoreLastSessionIfNeeded() {
        guard !hasRestoredLastSession, let textView else { return }
        hasRestoredLastSession = true

        do {
            if let url = AutosaveStore.lastDocumentURL, FileManager.default.fileExists(atPath: url.path) {
                try loadDocument(from: url, into: textView)
                currentDocumentURL = url
                AutosaveStore.saveLastDocumentURL(url)
                clearDocumentEdited()
                setDocumentStatus("Opened last document")
                return
            }

            setDocumentStatus("Ready")
        } catch {
            setDocumentStatus("Could not restore last document")
        }
    }

    func flushAutosave() {
        pendingAutosaveWorkItem?.cancel()
        pendingAutosaveWorkItem = nil
        guard isAutosaveEnabled else { return }
        performAutosave()
    }

    func confirmQuit() -> NSApplication.TerminateReply {
        guard isDocumentEdited else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to save changes before quitting?"
        alert.informativeText = "If you do not save, your changes will be lost."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveDocument() ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    func openDocument() {
        guard let textView else { return }

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
            clearDocumentEdited()
            setDocumentStatus("Opened")
        } catch {
            showError(error, message: "The document could not be opened.")
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
            updateWindowTitle(for: url)
            clearDocumentEdited()
            setDocumentStatus("Saved")
            return true
        } catch {
            showError(error, message: "The document could not be saved.")
            setDocumentStatus("Save failed")
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
            updateWindowTitle(for: url)
            clearDocumentEdited()
            setDocumentStatus("Saved")
            return true
        } catch {
            showError(error, message: "The document could not be saved.")
            setDocumentStatus("Save failed")
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
        } catch {
            showError(error, message: "The PDF could not be exported.")
        }
    }

    private func scheduleAutosave() {
        guard isAutosaveEnabled else { return }
        guard currentDocumentURL != nil else { return }
        pendingAutosaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingAutosaveWorkItem = nil
            self?.performAutosave()
        }

        pendingAutosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func performAutosave() {
        guard let textView else { return }
        guard isAutosaveEnabled else { return }
        guard isDocumentEdited else { return }
        guard let url = currentDocumentURL else {
            setDocumentStatus("Unsaved changes")
            return
        }

        do {
            try writeDocument(to: url)
            AutosaveStore.saveLastDocumentURL(url)
            updateWindowTitle(for: url)
            isDocumentEdited = false
            textView.window?.isDocumentEdited = false
            setDocumentStatus("Autosaved")
        } catch {
            setDocumentStatus("Autosave failed")
        }
    }

    private func setDocumentStatus(_ text: String) {
        if documentStatusText != text {
            documentStatusText = text
        }
    }

    private func loadDocument(from url: URL, into textView: AutocompleteTextView) throws {
        let attributedString = try documentFileStore.readDocument(from: url)

        textView.textStorage?.setAttributedString(attributedString)
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

    private func showError(_ error: Error, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
