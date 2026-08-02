import SwiftUI

enum TitlebarDocumentTitleLayout {
    static let maximumWidth: CGFloat = 160
    static let height: CGFloat = 24
    static let cornerRadius: CGFloat = 11
}

struct TitlebarDocumentTitleState: Equatable {
    var draftTitle: String
    var displayTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : draftTitle
    }

    init(documentTitle: String) {
        draftTitle = documentTitle
    }

    mutating func prepareForEditing(documentTitle: String) {
        draftTitle = documentTitle
    }

    mutating func syncDocumentTitle(_ documentTitle: String, isEditing: Bool) {
        guard !isEditing else { return }
        draftTitle = documentTitle
    }
}
