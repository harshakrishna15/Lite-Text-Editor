import AppKit
import UniformTypeIdentifiers

private let editableDocumentContentTypes: [UTType] = [
    .rtf,
    .plainText,
    .docxTextDocument,
    .odtTextDocument
]

extension EditorController {
    func markDocumentEdited() {
        if !isDocumentEdited {
            isDocumentEdited = true
            textView?.window?.isDocumentEdited = true
        }

        setDocumentStatus(currentDocumentURL == nil ? "Unsaved changes" : "Edited")
    }

    func setContinuousSpellCheckingEnabled(_ isEnabled: Bool) {
        guard isContinuousSpellCheckingEnabled != isEnabled else { return }

        isContinuousSpellCheckingEnabled = isEnabled
        WritingSettingsStore.saveIsContinuousSpellCheckingEnabled(isEnabled)
        textView?.isContinuousSpellCheckingEnabled = isEnabled
    }

    func setGrammarCheckingEnabled(_ isEnabled: Bool) {
        guard isGrammarCheckingEnabled != isEnabled else { return }

        isGrammarCheckingEnabled = isEnabled
        WritingSettingsStore.saveIsGrammarCheckingEnabled(isEnabled)
        textView?.isGrammarCheckingEnabled = isEnabled
    }

    func setAutomaticTextReplacementEnabled(_ isEnabled: Bool) {
        guard isAutomaticTextReplacementEnabled != isEnabled else { return }

        isAutomaticTextReplacementEnabled = isEnabled
        TextCorrectionSettingsStore.saveIsAutomaticReplacementEnabled(isEnabled)
        textView?.isAutomaticSpellingCorrectionEnabled = isEnabled
        textView?.isAutomaticTextReplacementEnabled = isEnabled
    }

    func setAutomaticQuoteSubstitutionEnabled(_ isEnabled: Bool) {
        guard isAutomaticQuoteSubstitutionEnabled != isEnabled else { return }

        isAutomaticQuoteSubstitutionEnabled = isEnabled
        WritingSettingsStore.saveIsAutomaticQuoteSubstitutionEnabled(isEnabled)
        textView?.isAutomaticQuoteSubstitutionEnabled = isEnabled
    }

    func setAutomaticDashSubstitutionEnabled(_ isEnabled: Bool) {
        guard isAutomaticDashSubstitutionEnabled != isEnabled else { return }

        isAutomaticDashSubstitutionEnabled = isEnabled
        WritingSettingsStore.saveIsAutomaticDashSubstitutionEnabled(isEnabled)
        textView?.isAutomaticDashSubstitutionEnabled = isEnabled
    }

    func setInlineSuggestionsEnabled(_ isEnabled: Bool) {
        guard isInlineSuggestionsEnabled != isEnabled else { return }

        isInlineSuggestionsEnabled = isEnabled
        AutocompleteSettingsStore.saveIsInlineSuggestionsEnabled(isEnabled)
        textView?.isInlineSuggestionEnabled = isEnabled
    }

    func setShouldReopenLastDocument(_ isEnabled: Bool) {
        guard shouldReopenLastDocument != isEnabled else { return }

        shouldReopenLastDocument = isEnabled
        StartupSettingsStore.saveShouldReopenLastDocument(isEnabled)
    }

    func clearDocumentEdited() {
        isDocumentEdited = false
        textView?.window?.isDocumentEdited = false
    }

    func restoreLastSessionIfNeeded() {
        guard !hasRestoredLastSession, let textView else { return }
        hasRestoredLastSession = true

        guard shouldReopenLastDocument else {
            setDocumentStatus("Ready")
            return
        }

        if let url = LastDocumentStore.lastDocumentURL, FileManager.default.fileExists(atPath: url.path) {
            loadDocumentInBackground(
                from: url,
                into: textView,
                successStatus: "Opened last document",
                failureMessage: "The last document could not be restored.",
                showsErrorOnFailure: false,
                onFailure: { [weak self] in
                    LastDocumentStore.clearLastDocumentURL()
                    self?.resetToBlankDocument()
                    self?.setDocumentStatus("Could not restore last document")
                }
            )
            return
        }

        setDocumentStatus("Ready")
    }

    func prepareTitleForLastRestorableDocument() {
        guard shouldReopenLastDocument else { return }
        guard let url = LastDocumentStore.lastDocumentURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        documentTitle = title(from: url)
    }

    func confirmQuit() -> NSApplication.TerminateReply {
        guard isDocumentEdited else {
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
        panel.allowedContentTypes = editableDocumentContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        loadDocumentInBackground(
            from: url,
            into: textView,
            successStatus: "Opened",
            failureMessage: "The document could not be opened."
        )
    }

    func openRecentDocument(_ url: URL) {
        guard let textView else { return }
        guard confirmUnsavedChanges(messageText: "Do you want to save changes before opening \(url.lastPathComponent)?") else { return }

        loadDocumentInBackground(
            from: url,
            into: textView,
            successStatus: "Opened",
            failureMessage: "The recent document could not be opened.",
            onFailure: { [weak self] in
                self?.recentDocumentStore.remove(url)
                self?.postRecentDocumentsChanged()
            }
        )
    }

    func commitDocumentTitle(_ title: String) {
        let nextTitle = sanitizedDocumentTitle(title)
        guard nextTitle != documentTitle else { return }

        guard let currentDocumentURL else {
            documentTitle = nextTitle
            setDocumentStatus("Title updated")
            return
        }

        let fileExtension = currentDocumentURL.pathExtension.isEmpty ? "rtf" : currentDocumentURL.pathExtension
        let newURL = currentDocumentURL
            .deletingLastPathComponent()
            .appendingPathComponent(nextTitle)
            .appendingPathExtension(fileExtension)

        guard newURL.standardizedFileURL.path != currentDocumentURL.standardizedFileURL.path else {
            documentTitle = nextTitle
            return
        }

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            showMessage("The document could not be renamed.", informativeText: "A file named \(newURL.lastPathComponent) already exists.")
            return
        }

        do {
            try FileManager.default.moveItem(at: currentDocumentURL, to: newURL)
            recentDocumentStore.remove(currentDocumentURL)
            self.currentDocumentURL = newURL
            documentTitle = nextTitle
            LastDocumentStore.saveLastDocumentURL(newURL)
            noteRecentDocument(newURL)
            updateWindowTitle(for: newURL)
            setDocumentStatus("Renamed")
        } catch {
            showError(error, message: "The document could not be renamed.")
        }
    }

    var documentLocationDisplayText: String {
        let directoryURL = documentDirectoryURLForPanels
        let folderName = directoryURL.lastPathComponent
        return folderName.isEmpty ? directoryURL.path : folderName
    }

    var defaultDocumentDirectoryURL: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
            .standardizedFileURL
            ?? FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
    }

    var documentDirectoryURLForPanels: URL {
        currentDocumentURL?.deletingLastPathComponent().standardizedFileURL
            ?? pendingDocumentDirectoryURL
            ?? defaultDocumentDirectoryURL
    }

    func chooseDocumentSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = documentDirectoryURLForPanels

        guard panel.runModal() == .OK, let directoryURL = panel.url else { return }
        updateDocumentDirectory(to: directoryURL)
    }

    func updateDocumentDirectory(to directoryURL: URL) {
        let standardizedDirectoryURL = directoryURL.standardizedFileURL

        guard let currentDocumentURL else {
            pendingDocumentDirectoryURL = standardizedDirectoryURL
            setDocumentStatus("Location updated")
            return
        }

        let newURL = documentURL(
            moving: currentDocumentURL,
            toDirectory: standardizedDirectoryURL
        )

        guard newURL.standardizedFileURL.path != currentDocumentURL.standardizedFileURL.path else {
            pendingDocumentDirectoryURL = nil
            setDocumentStatus("Location unchanged")
            return
        }

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            showMessage("The document could not be moved.", informativeText: "A file named \(newURL.lastPathComponent) already exists in \(standardizedDirectoryURL.path).")
            return
        }

        do {
            try FileManager.default.moveItem(at: currentDocumentURL, to: newURL)
            recentDocumentStore.remove(currentDocumentURL)
            self.currentDocumentURL = newURL
            pendingDocumentDirectoryURL = nil
            LastDocumentStore.saveLastDocumentURL(newURL)
            noteRecentDocument(newURL)
            updateWindowTitle(for: newURL)
            setDocumentStatus("Moved")
        } catch {
            showError(error, message: "The document could not be moved.")
        }
    }

    @discardableResult
    func saveDocument() -> Bool {
        guard let url = currentDocumentURL else {
            return saveDocumentAs()
        }

        do {
            try writeDocument(to: url)
            LastDocumentStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
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

    func saveDocumentInBackground() {
        guard let url = currentDocumentURL else {
            saveDocumentAsInBackground()
            return
        }

        guard let snapshot = documentSnapshot() else { return }
        beginBackgroundDocumentWrite(
            snapshot.attributedString,
            to: url,
            generation: snapshot.generation,
            updatesDocumentURL: false
        )
    }

    @discardableResult
    func saveDocumentAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = editableDocumentContentTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedDocumentName(fileExtension: "rtf")
        panel.directoryURL = documentDirectoryURLForPanels

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }

        let url = documentFileStore.normalizedTextDocumentURL(selectedURL)

        do {
            try writeDocument(to: url)
            currentDocumentURL = url
            pendingDocumentDirectoryURL = nil
            documentTitle = title(from: url)
            LastDocumentStore.saveLastDocumentURL(url)
            noteRecentDocument(url)
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

    func saveDocumentAsInBackground() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = editableDocumentContentTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedDocumentName(fileExtension: "rtf")
        panel.directoryURL = documentDirectoryURLForPanels

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let url = documentFileStore.normalizedTextDocumentURL(selectedURL)
        guard let snapshot = documentSnapshot() else { return }
        beginBackgroundDocumentWrite(
            snapshot.attributedString,
            to: url,
            generation: snapshot.generation,
            updatesDocumentURL: true
        )
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedDocumentName(fileExtension: "pdf")
        panel.directoryURL = documentDirectoryURLForPanels

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let url = documentFileStore.normalizedPDFURL(selectedURL)
        guard let snapshot = documentSnapshot() else { return }
        let operationID = UUID()
        exportOperationID = operationID
        setDocumentStatus("Exporting PDF...")

        documentFileService.writePDF(snapshot.attributedString, to: url) { [weak self] result in
            guard let self, self.exportOperationID == operationID else { return }

            switch result {
            case .success:
                self.setDocumentStatus("Exported PDF")
            case .failure(let error):
                self.showError(error, message: "The PDF could not be exported.")
                self.setDocumentStatus("Export failed")
            }
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
        pendingDocumentDirectoryURL = nil
        documentTitle = "Untitled"
        LastDocumentStore.clearLastDocumentURL()
        textView.window?.title = ChromeStyle.windowTitle
        textView.window?.representedURL = nil
        textView.resizeForCurrentPages()
        textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        textView.refreshSuggestion()
        textView.undoManager?.removeAllActions()
        refreshDocumentStatistics()
        refreshFormattingState()
        clearDocumentEdited()
    }

    private func loadDocumentInBackground(
        from url: URL,
        into textView: AutocompleteTextView,
        successStatus: String,
        failureMessage: String,
        showsErrorOnFailure: Bool = true,
        onFailure: (() -> Void)? = nil
    ) {
        let operationID = UUID()
        documentOperationID = operationID
        setDocumentStatus("Opening...")

        documentFileService.readDocument(from: url) { [weak self, weak textView] result in
            guard let self, self.documentOperationID == operationID, let textView else { return }

            switch result {
            case .success(let attributedString):
                self.applyLoadedDocument(attributedString, from: url, into: textView)
                self.currentDocumentURL = url
                self.pendingDocumentDirectoryURL = nil
                LastDocumentStore.saveLastDocumentURL(url)
                self.noteRecentDocument(url)
                self.clearDocumentEdited()
                self.setDocumentStatus(successStatus)
            case .failure(let error):
                onFailure?()
                if showsErrorOnFailure {
                    self.showError(error, message: failureMessage)
                }
                if self.documentStatusText == "Opening..." {
                    self.setDocumentStatus("Open failed")
                }
            }
        }
    }

    private func applyLoadedDocument(
        _ attributedString: NSAttributedString,
        from url: URL,
        into textView: AutocompleteTextView
    ) {
        textView.textStorage?.setAttributedString(attributedString)
        textView.contentGeneration &+= 1
        textView.invalidatePageMeasurementCache()
        textView.typingAttributes = documentFileStore.defaultTypingAttributes
        textView.resizeForCurrentPages()
        textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        textView.refreshSuggestion()
        textView.undoManager?.removeAllActions()
        updateWindowTitle(for: url)
        documentTitle = title(from: url)
        refreshDocumentStatistics()
        refreshFormattingState()
    }

    private func beginBackgroundDocumentWrite(
        _ attributedString: NSAttributedString,
        to url: URL,
        generation: Int,
        updatesDocumentURL: Bool
    ) {
        let operationID = UUID()
        documentOperationID = operationID
        setDocumentStatus("Saving...")

        documentFileService.writeDocument(attributedString, to: url) { [weak self] result in
            guard let self, self.documentOperationID == operationID else { return }

            switch result {
            case .success:
                if updatesDocumentURL {
                    self.currentDocumentURL = url
                    self.pendingDocumentDirectoryURL = nil
                    self.documentTitle = self.title(from: url)
                }

                LastDocumentStore.saveLastDocumentURL(url)
                self.noteRecentDocument(url)
                self.updateWindowTitle(for: url)

                if self.textView?.contentGeneration == generation {
                    self.clearDocumentEdited()
                    self.setDocumentStatus("Saved")
                } else {
                    self.setDocumentStatus("Saved previous changes")
                }
            case .failure(let error):
                self.showError(error, message: "The document could not be saved.")
                self.setDocumentStatus("Save failed")
            }
        }
    }

    private func documentSnapshot() -> (attributedString: NSAttributedString, generation: Int)? {
        guard let textView,
              let attributedString = textView.textStorage?.copy() as? NSAttributedString else {
            return nil
        }

        return (attributedString, textView.contentGeneration)
    }

    private func writeDocument(to url: URL) throws {
        guard let attributedString = documentSnapshot()?.attributedString else { return }
        try documentFileStore.writeDocument(attributedString, to: url)
    }

    private func writePDF(to url: URL) throws {
        guard let attributedString = documentSnapshot()?.attributedString else { return }
        try documentFileStore.writePDF(attributedString, to: url)
    }

    private func updateWindowTitle(for url: URL) {
        textView?.window?.title = ChromeStyle.windowTitle
        textView?.window?.representedURL = url
    }

    func documentURL(moving currentURL: URL, toDirectory directoryURL: URL) -> URL {
        directoryURL
            .standardizedFileURL
            .appendingPathComponent(currentURL.lastPathComponent)
    }

    private func suggestedDocumentName(fileExtension: String) -> String {
        if let currentDocumentURL {
            return documentFileStore.suggestedDocumentName(
                currentDocumentURL: currentDocumentURL,
                fileExtension: fileExtension
            )
        }

        return sanitizedDocumentTitle(documentTitle) + ".\(fileExtension)"
    }

    private func sanitizedDocumentTitle(_ title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let sanitizedTitle = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitizedTitle.isEmpty ? "Untitled" : sanitizedTitle
    }

    private func title(from url: URL) -> String {
        let title = url.deletingPathExtension().lastPathComponent
        return title.isEmpty ? "Untitled" : title
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

    private func showMessage(_ message: String, informativeText: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = informativeText
        alert.runModal()
    }
}

private extension UTType {
    static let docxTextDocument = UTType(filenameExtension: "docx")
        ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")

    static let odtTextDocument = UTType(filenameExtension: "odt")
        ?? UTType(importedAs: "org.oasis-open.opendocument.text")
}
