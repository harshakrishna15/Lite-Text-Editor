import AppKit
import Foundation

struct DocumentFileStore {
    static let supportedTextFileExtensions = Set(["rtf", "txt", "docx", "odt"])

    let defaultTypingAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.black
    ]

    func readDocument(from url: URL) throws -> NSAttributedString {
        switch url.pathExtension.lowercased() {
        case "rtf", "docx", "odt":
            guard let documentType = attributedStringDocumentType(for: url) else {
                throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
            }

            return try readAttributedString(from: url, documentType: documentType)
        case "txt":
            let string = try readPlainText(from: url)
            return NSAttributedString(string: string, attributes: defaultTypingAttributes)
        default:
            throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
        }
    }

    func writeDocument(_ attributedString: NSAttributedString, to url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "rtf", "docx", "odt":
            guard let documentType = attributedStringDocumentType(for: url) else {
                throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
            }

            try writeRichText(attributedString, to: url, documentType: documentType)
        case "txt":
            try attributedString.string.write(to: url, atomically: true, encoding: .utf8)
        default:
            try writeRichText(attributedString, to: url.appendingPathExtension("rtf"), documentType: .rtf)
        }
    }

    func writePDF(_ attributedString: NSAttributedString, to url: URL) throws {
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: AutocompleteTextView.paperWidth,
            height: AutocompleteTextView.pageHeight
        )

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentFileStoreError.couldNotCreatePDF
        }

        let exportStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        exportStorage.addLayoutManager(layoutManager)

        let pageContentSize = NSSize(
            width: AutocompleteTextView.pageTextWidth,
            height: AutocompleteTextView.pageContentHeight
        )

        guard exportStorage.length > 0 else {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(mediaBox)
            context.endPDFPage()
            context.closePDF()
            return
        }

        layoutManager.ensureGlyphs(forCharacterRange: NSRange(location: 0, length: exportStorage.length))
        let glyphCount = layoutManager.numberOfGlyphs
        var glyphLocation = 0
        var pageRanges: [NSRange] = []

        while glyphLocation < glyphCount {
            let container = NSTextContainer(containerSize: pageContentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }

            pageRanges.append(glyphRange)
            glyphLocation = NSMaxRange(glyphRange)
        }

        if pageRanges.isEmpty {
            pageRanges = [NSRange(location: 0, length: glyphCount)]
        }

        for glyphRange in pageRanges {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(mediaBox)

            context.saveGState()
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let contentOrigin = NSPoint(
                x: AutocompleteTextView.pageMargin,
                y: AutocompleteTextView.pageMargin
            )
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: contentOrigin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: contentOrigin)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()

            context.endPDFPage()
        }

        context.closePDF()
    }

    func normalizedTextDocumentURL(_ url: URL) -> URL {
        let fileExtension = url.pathExtension.lowercased()

        if Self.supportedTextFileExtensions.contains(fileExtension) {
            return url
        }

        return url.appendingPathExtension("rtf")
    }

    func normalizedPDFURL(_ url: URL) -> URL {
        url.pathExtension.lowercased() == "pdf" ? url : url.appendingPathExtension("pdf")
    }

    func suggestedDocumentName(currentDocumentURL: URL?, fileExtension: String) -> String {
        if let currentDocumentURL {
            return currentDocumentURL.deletingPathExtension().lastPathComponent + ".\(fileExtension)"
        }

        return "Untitled.\(fileExtension)"
    }

    private func readPlainText(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return try String(contentsOf: url, encoding: .macOSRoman)
        }
    }

    private func readAttributedString(
        from url: URL,
        documentType: NSAttributedString.DocumentType
    ) throws -> NSAttributedString {
        let data = try Data(contentsOf: url)
        return try NSAttributedString(
            data: data,
            options: [.documentType: documentType],
            documentAttributes: nil
        )
    }

    private func writeRichText(
        _ attributedString: NSAttributedString,
        to url: URL,
        documentType: NSAttributedString.DocumentType
    ) throws {
        let range = NSRange(location: 0, length: attributedString.length)
        let data = try attributedString.data(
            from: range,
            documentAttributes: [.documentType: documentType]
        )
        try data.write(to: url, options: .atomic)
    }

    private func attributedStringDocumentType(for url: URL) -> NSAttributedString.DocumentType? {
        switch url.pathExtension.lowercased() {
        case "rtf":
            return .rtf
        case "docx":
            return .officeOpenXML
        case "odt":
            return .openDocument
        default:
            return nil
        }
    }
}

enum DocumentFileStoreError: LocalizedError {
    case unsupportedFileType(String)
    case couldNotCreatePDF

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let fileExtension):
            return "Unsupported file type: .\(fileExtension)"
        case .couldNotCreatePDF:
            return "Lite Text Editor could not create the PDF file."
        }
    }
}
