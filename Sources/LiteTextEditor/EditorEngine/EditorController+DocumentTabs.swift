import AppKit

extension EditorController {
    var selectedDocumentTab: DocumentTabDescriptor? {
        guard let selectedDocumentTabID else { return nil }
        return documentTabs.first { $0.id == selectedDocumentTabID }
    }

    var canCloseDocumentTab: Bool {
        documentTabs.count > 1
    }

    var requiresNativeDocumentFormat: Bool {
        guard documentTabs.count == 1, let onlyTab = documentTabs.first else { return true }
        guard EditorDocument.isLegacyCompatibleTabTitle(onlyTab.title) else { return true }
        return nextAutomaticDocumentTabNumber != EditorDocument.defaultNextAutomaticTabNumber
    }

    func addDocumentTab(named requestedTitle: String? = nil) {
        flushSelectedDocumentTab()

        let id = UUID()
        let title = requestedTitle.map { uniqueDocumentTabTitle(basedOn: $0) }
            ?? nextAutomaticDocumentTabTitle()
        let descriptor = DocumentTabDescriptor(id: id, title: title)
        documentTabs.append(descriptor)
        documentTabContents[id] = blankTabContents()
        documentTabUndoManagers[id] = makeDocumentTabUndoManager()
        selectedDocumentTabID = id
        loadSelectedDocumentTab()
        markDocumentEdited()
    }

    func duplicateDocumentTab(_ id: UUID) {
        flushSelectedDocumentTab()
        guard let descriptor = documentTabs.first(where: { $0.id == id }),
              let contents = documentTabContents[id] else { return }

        let duplicateID = UUID()
        let duplicate = DocumentTabDescriptor(
            id: duplicateID,
            title: uniqueDocumentTabTitle(basedOn: "\(descriptor.title) Copy")
        )
        let insertionIndex = (documentTabs.firstIndex(where: { $0.id == id }) ?? documentTabs.endIndex - 1) + 1
        documentTabs.insert(duplicate, at: min(insertionIndex, documentTabs.endIndex))
        documentTabContents[duplicateID] = NSAttributedString(attributedString: contents)
        documentTabUndoManagers[duplicateID] = makeDocumentTabUndoManager()
        selectedDocumentTabID = duplicateID
        loadSelectedDocumentTab()
        markDocumentEdited()
    }

    func selectDocumentTab(_ id: UUID) {
        guard id != selectedDocumentTabID,
              documentTabs.contains(where: { $0.id == id }) else { return }

        flushSelectedDocumentTab()
        selectedDocumentTabID = id
        loadSelectedDocumentTab()
    }

    func requestCloseDocumentTab(_ id: UUID) {
        guard canCloseDocumentTab else { return }

        if let contents = contentsForDocumentTab(id), contents.length > 0 {
            let title = documentTabs.first(where: { $0.id == id })?.title ?? "Tab"
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Close “\(title)”?"
            alert.informativeText = "The contents of this tab will be removed from the document."
            alert.addButton(withTitle: "Close Tab")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        closeDocumentTab(id)
    }

    func closeDocumentTab(_ id: UUID) {
        guard documentTabs.count > 1,
              let index = documentTabs.firstIndex(where: { $0.id == id }) else { return }

        flushSelectedDocumentTab()
        let wasSelected = selectedDocumentTabID == id
        documentTabs.remove(at: index)
        documentTabContents.removeValue(forKey: id)
        documentTabSelections.removeValue(forKey: id)
        documentTabVisibleOrigins.removeValue(forKey: id)
        documentTabUndoManagers.removeValue(forKey: id)

        if wasSelected {
            let nextIndex = min(index, documentTabs.count - 1)
            selectedDocumentTabID = documentTabs[nextIndex].id
            loadSelectedDocumentTab()
        }

        markDocumentEdited()
    }

    func promptToRenameDocumentTab(_ id: UUID) {
        guard let descriptor = documentTabs.first(where: { $0.id == id }) else { return }

        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.informativeText = "Choose a short name for this part of the document."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: descriptor.title)
        field.placeholderString = "Tab name"
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let normalized = sanitizedDocumentTabTitle(field.stringValue) else { return }

        if normalized != descriptor.title,
           automaticDocumentTabNumber(from: normalized) != nil {
            let reservedNameAlert = NSAlert()
            reservedNameAlert.alertStyle = .informational
            reservedNameAlert.messageText = "Choose a Custom Tab Name"
            reservedNameAlert.informativeText = "Names such as “Tab 4” are reserved so automatic tab numbering stays in order."
            reservedNameAlert.addButton(withTitle: "OK")
            reservedNameAlert.runModal()
            return
        }

        renameDocumentTab(id, to: normalized)
    }

    func renameDocumentTab(_ id: UUID, to requestedTitle: String) {
        guard let index = documentTabs.firstIndex(where: { $0.id == id }) else { return }
        guard let normalized = sanitizedDocumentTabTitle(requestedTitle) else { return }
        guard normalized != documentTabs[index].title else { return }
        guard automaticDocumentTabNumber(from: normalized) == nil else { return }

        documentTabs[index].title = uniqueDocumentTabTitle(basedOn: normalized, excluding: id)
        markDocumentEdited()
    }

    func installDocument(_ document: EditorDocument, loadsSelectedTab: Bool = true) {
        let installedDocument = document.tabs.isEmpty ? EditorDocument.blank() : document
        let selectedID = installedDocument.tabs.contains(where: { $0.id == installedDocument.selectedTabID })
            ? installedDocument.selectedTabID
            : installedDocument.tabs[0].id

        documentTabs = installedDocument.tabs.map {
            DocumentTabDescriptor(id: $0.id, title: normalizedDocumentTabTitle($0.title))
        }
        let derivedNextNumber = automaticDocumentTabNumber(after: documentTabs)
        let persistedNextNumber = installedDocument.nextAutomaticTabNumber.flatMap { number in
            (1...EditorDocument.maximumAutomaticTabNumber).contains(number) ? number : nil
        }
        nextAutomaticDocumentTabNumber = max(
            persistedNextNumber ?? derivedNextNumber,
            derivedNextNumber
        )
        documentTabContents = Dictionary(
            uniqueKeysWithValues: installedDocument.tabs.map { tab in
                (
                    tab.id,
                    EditorTypography.normalizedAttributedString(tab.attributedString)
                )
            }
        )
        selectedDocumentTabID = selectedID
        documentTabSelections = [:]
        documentTabVisibleOrigins = [:]
        documentTabUndoManagers = Dictionary(
            uniqueKeysWithValues: installedDocument.tabs.map { ($0.id, makeDocumentTabUndoManager()) }
        )
        documentGeneration = 0

        if loadsSelectedTab {
            loadSelectedDocumentTab()
        }
    }

    func editorDocumentSnapshot() -> (document: EditorDocument, generation: Int)? {
        flushSelectedDocumentTab()
        guard let selectedDocumentTabID, !documentTabs.isEmpty else { return nil }

        let tabs = documentTabs.compactMap { descriptor -> EditorDocumentTab? in
            guard let contents = documentTabContents[descriptor.id] else { return nil }
            return EditorDocumentTab(
                id: descriptor.id,
                title: descriptor.title,
                attributedString: NSAttributedString(attributedString: contents)
            )
        }
        guard tabs.count == documentTabs.count else { return nil }

        return (
            EditorDocument(
                tabs: tabs,
                selectedTabID: selectedDocumentTabID,
                nextAutomaticTabNumber: nextAutomaticDocumentTabNumber
            ),
            documentGeneration
        )
    }

    func flushSelectedDocumentTab() {
        guard let selectedDocumentTabID,
              let textView,
              let textStorage = textView.textStorage else { return }

        enforceEditorTypography(in: textView)
        documentTabContents[selectedDocumentTabID] = NSAttributedString(attributedString: textStorage)
        documentTabSelections[selectedDocumentTabID] = textView.selectedRange()
        if let scrollView {
            documentTabVisibleOrigins[selectedDocumentTabID] = scrollView.contentView.bounds.origin
        }
    }

    func enforceEditorTypography(in textView: AutocompleteTextView) {
        guard !isEnforcingEditorTypography else { return }
        isEnforcingEditorTypography = true
        defer { isEnforcingEditorTypography = false }

        if let textStorage = textView.textStorage {
            EditorTypography.enforceFont(in: textStorage)
        }
        textView.typingAttributes = EditorTypography.normalizedTypingAttributes(textView.typingAttributes)
    }

    func activateSelectedDocumentTabUndoManager() {
        guard let selectedDocumentTabID, let textView else { return }
        let manager = documentTabUndoManagers[selectedDocumentTabID] ?? makeDocumentTabUndoManager()
        documentTabUndoManagers[selectedDocumentTabID] = manager
        textView.documentUndoManager = manager
    }

    private func loadSelectedDocumentTab() {
        guard let selectedDocumentTabID,
              let textView,
              let contents = documentTabContents[selectedDocumentTabID] else { return }

        pendingDocumentStatisticsRefresh?.cancel()
        pendingDocumentStatisticsRefresh = nil
        pendingOutlineRefresh?.cancel()
        pendingOutlineRefresh = nil
        pendingFormattingStateRefresh?.cancel()
        pendingFormattingStateRefresh = nil
        textView.clearSuggestion()
        predictionState = .idle
        spellCorrectionState = .inactive
        textView.isSpellingCorrectionReviewActive = false
        textView.breakUndoCoalescing()
        activateSelectedDocumentTabUndoManager()

        let normalizedContents = EditorTypography.normalizedAttributedString(contents)
        textView.textStorage?.setAttributedString(normalizedContents)
        documentTabContents[selectedDocumentTabID] = normalizedContents
        textView.contentGeneration &+= 1
        textView.invalidatePageMeasurementCache()

        let storedSelection = documentTabSelections[selectedDocumentTabID] ?? NSRange(location: 0, length: 0)
        let length = normalizedContents.length
        let location = min(max(storedSelection.location, 0), length)
        let selection = NSRange(location: location, length: min(storedSelection.length, length - location))
        textView.resizeForCurrentPages()

        if let origin = documentTabVisibleOrigins[selectedDocumentTabID], let scrollView {
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        } else {
            textView.moveInsertionPointToDocumentStartAndScrollToPageTop()
        }

        textView.setSelectedRange(selection)
        textView.typingAttributes = typingAttributes(for: normalizedContents, selection: selection)
        textView.refreshSuggestion()
        refreshDocumentStatistics()
        refreshFormattingState()
        textView.window?.makeFirstResponder(textView)
    }

    private func contentsForDocumentTab(_ id: UUID) -> NSAttributedString? {
        if id == selectedDocumentTabID {
            flushSelectedDocumentTab()
        }
        return documentTabContents[id]
    }

    private func blankTabContents() -> NSAttributedString {
        NSAttributedString(string: "", attributes: EditorTypography.defaultTypingAttributes)
    }

    private func makeDocumentTabUndoManager() -> UndoManager {
        let manager = UndoManager()
        manager.levelsOfUndo = 200
        return manager
    }

    private func typingAttributes(
        for attributedString: NSAttributedString,
        selection: NSRange
    ) -> [NSAttributedString.Key: Any] {
        guard attributedString.length > 0 else {
            return EditorTypography.defaultTypingAttributes
        }

        let location = min(selection.location, attributedString.length - 1)
        return EditorTypography.normalizedTypingAttributes(
            attributedString.attributes(at: location, effectiveRange: nil)
        )
    }

    private func normalizedDocumentTabTitle(_ title: String) -> String {
        sanitizedDocumentTabTitle(title) ?? "Untitled"
    }

    private func sanitizedDocumentTabTitle(_ title: String) -> String? {
        let singleLine = title
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else { return nil }
        return String(singleLine.prefix(40))
    }

    private func nextAutomaticDocumentTabTitle() -> String {
        let number = min(
            max(1, nextAutomaticDocumentTabNumber),
            EditorDocument.maximumAutomaticTabNumber
        )
        let title = uniqueDocumentTabTitle(basedOn: "Tab \(number)")
        if number < EditorDocument.maximumAutomaticTabNumber {
            nextAutomaticDocumentTabNumber = number + 1
        }
        return title
    }

    private func automaticDocumentTabNumber(after tabs: [DocumentTabDescriptor]) -> Int {
        let highestExistingNumber = tabs
            .compactMap { automaticDocumentTabNumber(from: $0.title) }
            .max() ?? 0
        let nextHighestNumber = min(
            highestExistingNumber + 1,
            EditorDocument.maximumAutomaticTabNumber
        )
        let nextPositionNumber = min(
            tabs.count,
            EditorDocument.maximumAutomaticTabNumber - 1
        ) + 1
        return max(nextHighestNumber, nextPositionNumber)
    }

    private func automaticDocumentTabNumber(from title: String) -> Int? {
        let components = title.split(separator: " ", omittingEmptySubsequences: false)
        guard components.count == 2,
              String(components[0]).caseInsensitiveCompare("Tab") == .orderedSame,
              let number = Int(components[1]),
              number > 0,
              number <= EditorDocument.maximumAutomaticTabNumber else { return nil }
        return number
    }

    private func uniqueDocumentTabTitle(basedOn title: String, excluding excludedID: UUID? = nil) -> String {
        let base = normalizedDocumentTabTitle(title)
        let existingTitles = Set(
            documentTabs
                .filter { $0.id != excludedID }
                .map { $0.title.lowercased() }
        )
        guard existingTitles.contains(base.lowercased()) else { return base }

        var index = 2
        while existingTitles.contains("\(base) \(index)".lowercased()) {
            index += 1
        }
        return "\(base) \(index)"
    }
}
