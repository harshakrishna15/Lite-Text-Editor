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
            selectedTabID: notesID,
            nextAutomaticTabNumber: 9
        )
        let url = temporaryFileURL(extension: NativeEditorDocumentCodec.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        try store.writeEditorDocument(document, to: url)
        let loaded = try store.readEditorDocument(from: url)

        XCTAssertEqual(loaded.tabs.map(\.id), [outlineID, notesID])
        XCTAssertEqual(loaded.tabs.map(\.title), ["Outline", "Notes"])
        XCTAssertEqual(loaded.selectedTabID, notesID)
        XCTAssertEqual(loaded.nextAutomaticTabNumber, 9)
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

    func testLegacyDocumentImportCreatesOneSelectedTabOne() throws {
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try "Imported legacy text".write(to: url, atomically: true, encoding: .utf8)

        let loaded = try store.readEditorDocument(from: url)

        XCTAssertEqual(loaded.tabs.count, 1)
        XCTAssertEqual(loaded.tabs[0].title, "Tab 1")
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
        XCTAssertEqual(loaded.tabs[0].title, "Draft")
        XCTAssertEqual(loaded.tabs[0].attributedString.string, "")
    }

    func testVersionOneNativeDocumentWithoutCounterStillContinuesFromHighestTab() throws {
        let tabOneID = UUID()
        let tabSevenID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabOneID,
                    title: "Tab 1",
                    attributedString: NSAttributedString(
                        string: "One",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                ),
                EditorDocumentTab(
                    id: tabSevenID,
                    title: "Tab 7",
                    attributedString: NSAttributedString(
                        string: "Seven",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabSevenID,
            nextAutomaticTabNumber: 12
        )
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try NativeEditorDocumentCodec.encode(document))
                as? [String: Any]
        )
        payload["version"] = 1
        payload.removeValue(forKey: "nextAutomaticTabNumber")
        let legacyData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let loaded = try NativeEditorDocumentCodec.decode(legacyData)
        XCTAssertNil(loaded.nextAutomaticTabNumber)

        let controller = EditorController()
        controller.installDocument(loaded, loadsSelectedTab: false)
        controller.addDocumentTab()

        XCTAssertEqual(controller.documentTabs.map(\.title), ["Tab 1", "Tab 7", "Tab 8"])
    }

    func testNativeDocumentRejectsOutOfRangeAutomaticTabCounter() {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: "Tab 1",
                    attributedString: NSAttributedString(
                        string: "",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID,
            nextAutomaticTabNumber: EditorDocument.maximumAutomaticTabNumber + 1
        )

        XCTAssertThrowsError(try NativeEditorDocumentCodec.encode(document))
    }

    func testWritingMultipleTabsToLegacyFormatIsRejected() {
        let firstID = UUID()
        let secondID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: firstID,
                    title: "Tab 1",
                    attributedString: NSAttributedString(string: "Tab 1", attributes: EditorTypography.defaultTypingAttributes)
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

    func testWritingDefaultSingleTabToLegacyFormatSucceeds() throws {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: EditorDocument.defaultTabTitle,
                    attributedString: NSAttributedString(
                        string: "A single tab",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID
        )
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try store.writeEditorDocument(document, to: url)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "A single tab")
    }

    func testWritingSingleDefaultTabWithAdvancedCounterToLegacyFormatIsRejected() {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: EditorDocument.defaultTabTitle,
                    attributedString: NSAttributedString(
                        string: "A single tab",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID,
            nextAutomaticTabNumber: 3
        )
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try store.writeEditorDocument(document, to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testWritingLegacyDraftSingleTabToLegacyFormatStillSucceeds() throws {
        let tabID = UUID()
        let document = EditorDocument(
            tabs: [
                EditorDocumentTab(
                    id: tabID,
                    title: EditorDocument.legacyDefaultTabTitle,
                    attributedString: NSAttributedString(
                        string: "An older single tab",
                        attributes: EditorTypography.defaultTypingAttributes
                    )
                )
            ],
            selectedTabID: tabID
        )
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try store.writeEditorDocument(document, to: url)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "An older single tab")
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
