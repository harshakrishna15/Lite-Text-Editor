import AppKit
import XCTest
@testable import LiteTextEditor

final class DocumentFileStoreTests: XCTestCase {
    private let store = DocumentFileStore()

    func testNormalizesPDFURLs() {
        let folder = URL(fileURLWithPath: "/tmp")

        XCTAssertEqual(
            store.normalizedPDFURL(folder.appendingPathComponent("draft")),
            folder.appendingPathComponent("draft.pdf")
        )
        XCTAssertEqual(
            store.normalizedPDFURL(folder.appendingPathComponent("draft.pdf")),
            folder.appendingPathComponent("draft.pdf")
        )
    }

    func testSuggestedDocumentNames() {
        let currentURL = URL(fileURLWithPath: "/tmp/Project Notes.rtf")

        XCTAssertEqual(
            store.suggestedDocumentName(currentDocumentURL: currentURL, fileExtension: "pdf"),
            "Project Notes.pdf"
        )
        XCTAssertEqual(
            store.suggestedDocumentName(currentDocumentURL: nil, fileExtension: "rtf"),
            "Untitled.rtf"
        )
    }

    func testPlainTextRoundTrip() throws {
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = NSAttributedString(
            string: "Plain text document",
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )

        try store.writeDocument(document, to: url)
        let loaded = try store.readDocument(from: url)

        XCTAssertEqual(loaded.string, document.string)
        XCTAssertNotNil(loaded.attribute(.font, at: 0, effectiveRange: nil))
        XCTAssertNotNil(loaded.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    func testPlainTextReadDetectsUTF16Files() throws {
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let text = "Plain text with UTF-16: cafe \u{0301} and checkmark \u{2713}"
        let data = try XCTUnwrap(text.data(using: .utf16))
        try data.write(to: url)

        let loaded = try store.readDocument(from: url)

        XCTAssertEqual(loaded.string, text)
    }

    func testPlainTextReadFallsBackToWindowsLatinEncoding() throws {
        let url = temporaryFileURL(extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let text = "Curly \u{201c}quotes\u{201d} and euro \u{20ac}"
        let data = try XCTUnwrap(text.data(using: .windowsCP1252))
        try data.write(to: url)

        let loaded = try store.readDocument(from: url)

        XCTAssertEqual(loaded.string, text)
    }

    func testDocumentFileServiceExportsPDFAsynchronously() {
        let url = temporaryFileURL(extension: "pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DocumentFileService()
        let document = NSAttributedString(
            string: "Background PDF",
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )
        let exportExpectation = expectation(description: "export")

        service.writePDF(document, to: url) { result in
            do {
                try result.get()
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            } catch {
                XCTFail("PDF export failed: \(error)")
            }
            exportExpectation.fulfill()
        }

        wait(for: [exportExpectation], timeout: 2)
    }

    func testRTFRoundTripPreservesStringAndBasicAttributes() throws {
        let url = temporaryFileURL(extension: "rtf")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = NSAttributedString(
            string: "Styled document",
            attributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: NSColor.systemBlue
            ]
        )

        try store.writeDocument(document, to: url)
        let loaded = try store.readDocument(from: url)

        XCTAssertEqual(loaded.string, document.string)
        XCTAssertNotNil(loaded.attribute(.font, at: 0, effectiveRange: nil))
        XCTAssertNotNil(loaded.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    func testOfficeDocumentRoundTripsPreserveStringAndBasicAttributes() throws {
        for fileExtension in ["docx", "odt"] {
            let url = temporaryFileURL(extension: fileExtension)
            defer { try? FileManager.default.removeItem(at: url) }

            let document = NSAttributedString(
                string: "Styled document",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: NSColor.systemBlue
                ]
            )

            try store.writeDocument(document, to: url)
            let loaded = try store.readDocument(from: url)

            XCTAssertEqual(loaded.string.trimmingCharacters(in: .newlines), document.string)
            XCTAssertNotNil(loaded.attribute(.font, at: 0, effectiveRange: nil))
            XCTAssertNotNil(loaded.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        }
    }

    func testUnsupportedFileTypeReportsReadableError() {
        let url = URL(fileURLWithPath: "/tmp/document.md")

        XCTAssertThrowsError(try store.readDocument(from: url)) { error in
            XCTAssertEqual(error.localizedDescription, "Unsupported file type: .md")
        }
    }

    private func temporaryFileURL(extension fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }
}
