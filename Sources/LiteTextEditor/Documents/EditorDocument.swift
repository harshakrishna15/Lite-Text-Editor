import AppKit
import Foundation

struct DocumentTabDescriptor: Identifiable, Equatable {
    let id: UUID
    var title: String
}

struct EditorDocumentTab {
    let id: UUID
    var title: String
    var attributedString: NSAttributedString
}

struct EditorDocument {
    var tabs: [EditorDocumentTab]
    var selectedTabID: UUID

    static func blank() -> EditorDocument {
        let tab = EditorDocumentTab(
            id: UUID(),
            title: "Draft",
            attributedString: NSAttributedString(
                string: "",
                attributes: EditorTypography.defaultTypingAttributes
            )
        )
        return EditorDocument(tabs: [tab], selectedTabID: tab.id)
    }

    var selectedTab: EditorDocumentTab? {
        tabs.first { $0.id == selectedTabID }
    }
}

enum NativeEditorDocumentCodec {
    static let fileExtension = "ltedoc"
    private static let identifier = "com.openai.lite-text-editor.document"
    private static let currentVersion = 1

    static func encode(_ document: EditorDocument) throws -> Data {
        try validate(document)

        let tabs = try document.tabs.map { tab in
            NativeTab(
                id: tab.id,
                title: normalizedTitle(tab.title),
                rtfData: try rtfData(from: EditorTypography.normalizedAttributedString(tab.attributedString))
            )
        }
        let envelope = NativeEnvelope(
            identifier: identifier,
            version: currentVersion,
            selectedTabID: document.selectedTabID,
            tabs: tabs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    static func decode(_ data: Data) throws -> EditorDocument {
        let envelope: NativeEnvelope

        do {
            envelope = try JSONDecoder().decode(NativeEnvelope.self, from: data)
        } catch {
            throw NativeEditorDocumentError.invalidDocument
        }

        guard envelope.identifier == identifier else {
            throw NativeEditorDocumentError.invalidDocument
        }
        guard envelope.version <= currentVersion else {
            throw NativeEditorDocumentError.unsupportedVersion(envelope.version)
        }
        guard envelope.version > 0 else {
            throw NativeEditorDocumentError.invalidDocument
        }

        let tabs = try envelope.tabs.map { tab in
            EditorDocumentTab(
                id: tab.id,
                title: normalizedTitle(tab.title),
                attributedString: EditorTypography.normalizedAttributedString(
                    try attributedString(fromRTF: tab.rtfData)
                )
            )
        }
        let document = EditorDocument(tabs: tabs, selectedTabID: envelope.selectedTabID)
        try validate(document)
        return document
    }

    private static func validate(_ document: EditorDocument) throws {
        guard !document.tabs.isEmpty else {
            throw NativeEditorDocumentError.missingTabs
        }

        let ids = Set(document.tabs.map(\.id))
        guard ids.count == document.tabs.count else {
            throw NativeEditorDocumentError.duplicateTabIdentifiers
        }
        guard ids.contains(document.selectedTabID) else {
            throw NativeEditorDocumentError.invalidSelectedTab
        }
    }

    private static func normalizedTitle(_ title: String) -> String {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Untitled" : normalized
    }

    private static func rtfData(from attributedString: NSAttributedString) throws -> Data {
        try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    private static func attributedString(fromRTF data: Data) throws -> NSAttributedString {
        do {
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } catch {
            throw NativeEditorDocumentError.invalidTabContents
        }
    }

    private struct NativeEnvelope: Codable {
        let identifier: String
        let version: Int
        let selectedTabID: UUID
        let tabs: [NativeTab]
    }

    private struct NativeTab: Codable {
        let id: UUID
        let title: String
        let rtfData: Data
    }
}

enum NativeEditorDocumentError: LocalizedError {
    case invalidDocument
    case unsupportedVersion(Int)
    case missingTabs
    case duplicateTabIdentifiers
    case invalidSelectedTab
    case invalidTabContents

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "This is not a valid Lite Text Editor document."
        case .unsupportedVersion(let version):
            return "This document uses a newer unsupported format (version \(version))."
        case .missingTabs:
            return "This document does not contain any tabs."
        case .duplicateTabIdentifiers:
            return "This document contains duplicate tab identifiers."
        case .invalidSelectedTab:
            return "This document's selected tab is invalid."
        case .invalidTabContents:
            return "One of this document's tabs could not be read."
        }
    }
}
