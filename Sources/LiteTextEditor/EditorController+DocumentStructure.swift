import AppKit

extension EditorController {
    var outlineSummaryText: String {
        documentStructureMetadata.summaryText
    }

    var activeStructureText: String {
        guard let activeOutlineItem = outlineItems.first(where: { $0.id == activeOutlineItemID }) else {
            return ""
        }

        return "\(activeOutlineItem.displayTitle) - \(activeOutlineItem.metadataText)"
    }

    func refreshDocumentStatistics() {
        pendingDocumentStatisticsRefresh?.cancel()
        pendingDocumentStatisticsRefresh = nil

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
        guard let attributedString = textView?.textStorage else {
            if !outlineItems.isEmpty {
                outlineItems = []
            }
            if documentStructureMetadata != .empty {
                documentStructureMetadata = .empty
            }
            if activeOutlineItemID != nil {
                activeOutlineItemID = nil
            }
            return
        }

        let snapshot = DocumentOutlineExtractor().makeStructureSnapshot(from: attributedString)
        let nextItems = snapshot.items

        if nextItems != outlineItems {
            outlineItems = nextItems
        }

        if snapshot.metadata != documentStructureMetadata {
            documentStructureMetadata = snapshot.metadata
        }

        refreshActiveOutlineItem()
    }

    func scheduleDocumentStatisticsRefresh() {
        pendingDocumentStatisticsRefresh?.cancel()

        let textGeneration = textView?.contentGeneration
        let pageCount = textView?.currentPageCount
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.textView?.contentGeneration == textGeneration,
                  self.textView?.currentPageCount == pageCount else {
                self.scheduleDocumentStatisticsRefresh()
                return
            }

            self.refreshDocumentStatistics()
        }

        pendingDocumentStatisticsRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    func refreshActiveOutlineItem() {
        guard let textView, !outlineItems.isEmpty else {
            if activeOutlineItemID != nil {
                activeOutlineItemID = nil
            }
            return
        }

        let textLength = (textView.string as NSString).length
        let selectionLocation = min(max(textView.selectedRange().location, 0), textLength)
        let activeItem = outlineItems.last { item in
            item.location <= selectionLocation
        }
        let nextID = activeItem?.id

        if activeOutlineItemID != nextID {
            activeOutlineItemID = nextID
        }
    }

    func selectOutlineItem(_ item: DocumentOutlineItem) {
        guard let textView else { return }

        let textLength = (textView.string as NSString).length
        let location = min(max(item.location, 0), textLength)
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        let headingRange = NSRange(location: location, length: min(item.headingLength, textLength - location))
        textView.scrollRangeToVisible(headingRange)
        textView.showFindIndicator(for: headingRange)
        activeOutlineItemID = item.id
        documentStatusText = "Outline: \(item.displayTitle)"
    }

}
