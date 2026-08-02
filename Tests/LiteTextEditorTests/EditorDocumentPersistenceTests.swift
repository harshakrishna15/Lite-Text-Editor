import AppKit
import XCTest
@testable import LiteTextEditor

final class EditorDocumentPersistenceTests: XCTestCase {
    private let store = DocumentFileStore()

    func testNativeDocumentRoundTripPreservesTabsSelectionAndRichText() throws {
        let outlineID = UUID()
        let notesID = UUID()
        let outline = NSAttributedString(
            string: "Story outline",
            attributes: [
                .font: NSFont.systemFont(ofSize: 17, weight: .bold),
                .foregroundColor: NSColor.systemBlue
            ]
        )
        let notes = NSAttributedString(
            string: "Research notes",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(id: outlineID, title: "  Outline  ", attributedString: outline),
                EditorDocumentTab(id: notesID, title: "Notes", attributedString: notes)
            ],
            selectedTabID: notesID
        )
        let url = temporaryFileURL(extension: NativeEditorDocumentCodec.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        try store.writeEditorDocument(document, to: url)
        let loaded = try store.readEditorDocument(from: url)

        XCTAssertEqual(loaded.tabs.map(\.id), [outlineID, notesID])
        XCTAssertEqual(loaded.tabs.map(\.title), ["Outline", "Notes"])
        XCTAssertEqual(loaded.selectedTabID, notesID)
        XCTAssertEqual(loaded.tabs.map { $0.attributedString.string }, [outline.string, notes.string])

        let loadedOutlineFont = try XCTUnwrap(
            loaded.tabs[0].attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )
        let loadedNotesFont = try XCTUnwrap(
            loaded.tabs[1].attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(EditorTypography.isAllowedFont(loadedOutlineFont))
        XCTAssertEqual(loadedOutlineFont.pointSize, 17, accuracy: 0.001)
        XCTAssertTrue(loadedOutlineFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(EditorTypography.isAllowedFont(loadedNotesFont))
        XCTAssertEqual(loadedNotesFont.pointSize, 14, accuracy: 0.001)
        XCTAssertEqual(
            loaded.tabs[1].attributedString.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
    }

    func testLegacyDocumentImportCreatesOneSelectedDraftTab() throws {
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try "Imported legacy text".write(to: url, atomically: true, encoding: .utf8)

        let loaded = try store.readEditorDocument(from: url)

        XCTAssertEqual(loaded.tabs.count, 1)
        XCTAssertEqual(loaded.tabs[0].title, "Draft")
        XCTAssertEqual(loaded.selectedTabID, loaded.tabs[0].id)
        XCTAssertEqual(loaded.tabs[0].attributedString.string, "Imported legacy text")
        let font = try XCTUnwrap(
            loaded.tabs[0].attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(EditorTypography.isAllowedFont(font))
    }

    func testNativeDocumentRoundTripPreservesEmptyTab() throws {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: "Draft",
                    attributedString: NSAttributedString(
                        string: "",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID
        )
        let url = temporaryFileURL(extension: NativeEditorDocumentCodec.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        try store.writeEditorDocument(document, to: url)
        let loaded = try store.readEditorDocument(from: url)

        XCTAssertEqual(loaded.tabs.count, 1)
        XCTAssertEqual(loaded.tabs[0].id, tabID)
        XCTAssertEqual(loaded.tabs[0].attributedString.string, "")
    }

    func testWritingMultipleTabsToLegacyFormatIsRejected() {
        let firstID = UUID()
        let secondID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: firstID,
                    title: "Draft",
                    attributedString: NSAttributedString(string: "Draft", attributes: EditorTypography.defaultTypingAttributes)
                ),
                EditorDocumentTab(
                    id: secondID,
                    title: "Notes",
                    attributedString: NSAttributedString(string: "Notes", attributes: EditorTypography.defaultTypingAttributes)
                )
            ],
            selectedTabID: firstID
        )
        let url = temporaryFileURL(extension: "rtf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try store.writeEditorDocument(document, to: url)) { error in
            guard let storeError = error as? DocumentFileStoreError else {
                return XCTFail("Expected DocumentFileStoreError, got \(error)")
            }

            switch storeError {
            case .multipleTabsRequireNativeFormat:
                break
            default:
                XCTFail("Expected multipleTabsRequireNativeFormat, got \(storeError)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testWritingNamedSingleTabToLegacyFormatIsRejected() {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: "Outline",
                    attributedString: NSAttributedString(
                        string: "Outline",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID
        )
        let url = temporaryFileURL(extension: "rtf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try store.writeEditorDocument(document, to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    private func temporaryFileURL(extension fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }
}
