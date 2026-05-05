import SwiftUI

enum TitlebarDocumentTitleLayout {
    static let textAlignment: TextAlignment = .leading
    static let leadingGapAfterTrafficButtons: CGFloat = 2
    static let trailingInset: CGFloat = 20
    static let minimumWidth: CGFloat = 180
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
