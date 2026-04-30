import AppKit

extension EditorController {
    var outlineSummaryText: String {
        let sectionCount = outlineItems.filter { $0.level > 0 }.count

        if sectionCount > 0 {
            return "\(sectionCount) \(sectionCount == 1 ? "section" : "sections")"
        }

        guard !outlineItems.isEmpty else { return "No headings" }
        return "\(outlineItems.count) \(outlineItems.count == 1 ? "heading" : "headings")"
    }

    var activeStructureText: String {
        guard let activeOutlineItem = outlineItems.first(where: { $0.id == activeOutlineItemID }) else {
            return ""
        }

        return activeOutlineItem.displayTitle
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
            if activeOutlineItemID != nil {
                activeOutlineItemID = nil
            }
            return
        }

        let nextItems = DocumentOutlineExtractor().makeOutlineItems(from: attributedString)

        if nextItems != outlineItems {
            outlineItems = nextItems
        }

        refreshActiveOutlineItem()
    }

    func scheduleDocumentStatisticsRefresh() {
        pendingDocumentStatisticsRefresh?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshDocumentStatistics()
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
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
    }

}
