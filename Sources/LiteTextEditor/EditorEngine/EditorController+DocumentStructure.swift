import AppKit

private let documentStatisticsQueue = DispatchQueue(
    label: "LiteTextEditor.DocumentStatistics",
    qos: .userInitiated
)

private let documentStructureQueue = DispatchQueue(
    label: "LiteTextEditor.DocumentStructure",
    qos: .userInitiated
)

extension EditorController {
    var outlineSummaryText: String {
        documentStructureMetadata.summaryText
    }

    var currentOutlineHeadingText: String? {
        outlineItems.first(where: { $0.id == activeOutlineItemID })?.displayTitle
    }

    func refreshDocumentStatistics() {
        pendingDocumentStatisticsRefresh?.cancel()
        pendingDocumentStatisticsRefresh = nil
        pendingOutlineRefresh?.cancel()
        pendingOutlineRefresh = nil

        refreshOutlineItems()

        let nextStatistics = DocumentTextStatistics.make(
            from: textView?.string ?? "",
            pages: textView?.currentPageCount ?? 1
        )

        if nextStatistics != documentStatistics {
            documentStatistics = nextStatistics
        }
    }

    func refreshOutlineItems() {
        pendingOutlineRefresh?.cancel()
        pendingOutlineRefresh = nil

        guard let attributedString = textView?.textStorage else {
            clearOutlineStructure()
            return
        }

        let snapshot = DocumentOutlineExtractor().makeStructureSnapshot(from: attributedString)
        applyStructureSnapshot(snapshot)
    }

    func scheduleDocumentStatisticsRefresh() {
        pendingDocumentStatisticsRefresh?.cancel()
        scheduleOutlineRefresh()

        let textGeneration = textView?.contentGeneration
        let pageCount = textView?.currentPageCount
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.textView?.contentGeneration == textGeneration,
                  self.textView?.currentPageCount == pageCount else {
                self.scheduleDocumentStatisticsRefresh()
                return
            }

            self.pendingDocumentStatisticsRefresh = nil

            let text = self.textView?.string ?? ""
            let pageCount = self.textView?.currentPageCount ?? 1

            documentStatisticsQueue.async { [weak self] in
                let nextStatistics = DocumentTextStatistics.make(from: text, pages: pageCount)

                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.textView?.contentGeneration == textGeneration,
                          self.textView?.currentPageCount == pageCount else {
                        self.scheduleDocumentStatisticsRefresh()
                        return
                    }

                    if nextStatistics != self.documentStatistics {
                        self.documentStatistics = nextStatistics
                    }
                }
            }
        }

        pendingDocumentStatisticsRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    func scheduleOutlineRefresh() {
        pendingOutlineRefresh?.cancel()

        let textGeneration = textView?.contentGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.textView?.contentGeneration == textGeneration else {
                self.scheduleOutlineRefresh()
                return
            }

            self.pendingOutlineRefresh = nil
            guard let attributedSnapshot = self.textView?.textStorage?.copy() as? NSAttributedString else {
                self.clearOutlineStructure()
                return
            }

            documentStructureQueue.async { [weak self] in
                let snapshot = DocumentOutlineExtractor().makeStructureSnapshot(from: attributedSnapshot)

                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.textView?.contentGeneration == textGeneration else {
                        self.scheduleOutlineRefresh()
                        return
                    }

                    self.applyStructureSnapshot(snapshot)
                }
            }
        }

        pendingOutlineRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func refreshActiveOutlineItem() {
        guard let textView, !outlineItems.isEmpty else {
            if activeOutlineItemID != nil {
                activeOutlineItemID = nil
            }
            return
        }

        let textLength = textView.textStorageLength
        let selectionLocation = min(max(textView.selectedRange().location, 0), textLength)
        let activeItem = activeOutlineItem(at: selectionLocation)
        let nextID = activeItem?.id

        if activeOutlineItemID != nextID {
            activeOutlineItemID = nextID
        }
    }

    func selectOutlineItem(_ item: DocumentOutlineItem) {
        guard let textView else { return }

        let textLength = textView.textStorageLength
        let location = min(max(item.location, 0), textLength)
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        let headingRange = NSRange(location: location, length: min(item.headingLength, textLength - location))
        textView.scrollRangeToVisible(headingRange)
        textView.showFindIndicator(for: headingRange)
        activeOutlineItemID = item.id
        documentStatusText = "Outline: \(item.displayTitle)"
    }

    private func applyStructureSnapshot(_ snapshot: DocumentOutlineExtractor.StructureSnapshot) {
        if snapshot.items != outlineItems {
            outlineItems = snapshot.items
        }

        if snapshot.metadata != documentStructureMetadata {
            documentStructureMetadata = snapshot.metadata
        }

        refreshActiveOutlineItem()
    }

    private func clearOutlineStructure() {
        if !outlineItems.isEmpty {
            outlineItems = []
        }
        if documentStructureMetadata != .empty {
            documentStructureMetadata = .empty
        }
        if activeOutlineItemID != nil {
            activeOutlineItemID = nil
        }
    }

    private func activeOutlineItem(at selectionLocation: Int) -> DocumentOutlineItem? {
        var low = outlineItems.startIndex
        var high = outlineItems.endIndex

        while low < high {
            let mid = low + ((high - low) / 2)
            if outlineItems[mid].location <= selectionLocation {
                low = mid + 1
            } else {
                high = mid
            }
        }

        guard low > outlineItems.startIndex else { return nil }
        return outlineItems[low - 1]
    }

}
