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
        panel.nameFieldStringValue = suggestedDocumentName(extension: "rtf")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }

        let url = normalizedTextDocumentURL(selectedURL)

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
        panel.nameFieldStringValue = suggestedDocumentName(extension: "pdf")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let url = selectedURL.pathExtension.lowercased() == "pdf"
            ? selectedURL
            : selectedURL.appendingPathExtension("pdf")

        do {
            try writePDF(to: url)
        } catch {
            showError(error, message: "The PDF could not be exported.")
        }
    }

    private var defaultTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]
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

    private func readDocument(from url: URL) throws -> NSAttributedString {
        switch url.pathExtension.lowercased() {
        case "rtf":
            let data = try Data(contentsOf: url)
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        case "txt":
            let string = try readPlainText(from: url)
            return NSAttributedString(string: string, attributes: defaultTypingAttributes)
        default:
            throw DocumentError.unsupportedFileType(url.pathExtension)
        }
    }

    private func readPlainText(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return try String(contentsOf: url, encoding: .macOSRoman)
        }
    }

    private func loadDocument(from url: URL, into textView: AutocompleteTextView) throws {
        let attributedString = try readDocument(from: url)

        textView.textStorage?.setAttributedString(attributedString)
        textView.typingAttributes = defaultTypingAttributes
        textView.resizeForCurrentPages()
        textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        textView.refreshSuggestion()
        textView.undoManager?.removeAllActions()
        updateWindowTitle(for: url)
        refreshDocumentStatistics()
        refreshFormattingState()
    }

    private func writeDocument(to url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "rtf":
            try writeRTF(to: url)
        case "txt":
            try textView?.string.write(to: url, atomically: true, encoding: .utf8)
        default:
            try writeRTF(to: url.appendingPathExtension("rtf"))
        }
    }

    private func writeRTF(to url: URL) throws {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = NSRange(location: 0, length: textStorage.length)
        let data = try textStorage.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        try data.write(to: url, options: .atomic)
    }

    private func writePDF(to url: URL) throws {
        guard let textView, let textStorage = textView.textStorage else { return }

        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: AutocompleteTextView.paperWidth,
            height: AutocompleteTextView.pageHeight
        )

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentError.couldNotCreatePDF
        }

        let exportStorage = NSTextStorage(attributedString: textStorage)
        let layoutManager = NSLayoutManager()
        exportStorage.addLayoutManager(layoutManager)

        let pageContentSize = NSSize(
            width: AutocompleteTextView.pageTextWidth,
            height: AutocompleteTextView.pageContentHeight
        )

        guard exportStorage.length > 0 else {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(mediaBox)
            context.endPDFPage()
            context.closePDF()
            return
        }

        layoutManager.ensureGlyphs(forCharacterRange: NSRange(location: 0, length: exportStorage.length))
        let glyphCount = layoutManager.numberOfGlyphs
        var glyphLocation = 0
        var pageRanges: [NSRange] = []

        while glyphLocation < glyphCount {
            let container = NSTextContainer(containerSize: pageContentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }

            pageRanges.append(glyphRange)
            glyphLocation = NSMaxRange(glyphRange)
        }

        if pageRanges.isEmpty {
            pageRanges = [NSRange(location: 0, length: glyphCount)]
        }

        for glyphRange in pageRanges {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(mediaBox)

            context.saveGState()
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let contentOrigin = NSPoint(
                x: AutocompleteTextView.pageMargin,
                y: AutocompleteTextView.pageMargin
            )
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: contentOrigin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: contentOrigin)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()

            context.endPDFPage()
        }

        context.closePDF()
    }

    private func normalizedTextDocumentURL(_ url: URL) -> URL {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "rtf" || fileExtension == "txt" {
            return url
        }

        return url.appendingPathExtension("rtf")
    }

    private func suggestedDocumentName(extension fileExtension: String) -> String {
        if let currentDocumentURL {
            return currentDocumentURL.deletingPathExtension().lastPathComponent + ".\(fileExtension)"
        }

        return "Untitled.\(fileExtension)"
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

private enum DocumentError: LocalizedError {
    case unsupportedFileType(String)
    case couldNotCreatePDF

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let fileExtension):
            return "Unsupported file type: .\(fileExtension)"
        case .couldNotCreatePDF:
            return "Lite Text Editor could not create the PDF file."
        }
    }
}
