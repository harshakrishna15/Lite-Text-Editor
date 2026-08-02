import AppKit
import Foundation

struct DocumentFileStore {
    static let supportedTextFileExtensions = Set(["rtf", "txt", "docx", "odt"])
    static let supportedEditorDocumentFileExtensions = supportedTextFileExtensions.union([
        NativeEditorDocumentCodec.fileExtension
    ])
    private static let plainTextFallbackEncodings: [String.Encoding] = [
        .windowsCP1252,
        .isoLatin1,
        .macOSRoman
    ]

    let defaultTypingAttributes = EditorTypography.defaultTypingAttributes

    func readEditorDocument(from url: URL) throws -> EditorDocument {
        if url.pathExtension.lowercased() == NativeEditorDocumentCodec.fileExtension {
            return try NativeEditorDocumentCodec.decode(Data(contentsOf: url))
        }

        let attributedString = try readDocument(from: url)
        let tab = EditorDocumentTab(
            id: UUID(),
            title: EditorDocument.defaultTabTitle,
            attributedString: attributedString
        )
        return EditorDocument(tabs: [tab], selectedTabID: tab.id)
    }

    func writeEditorDocument(_ document: EditorDocument, to url: URL) throws {
        if url.pathExtension.lowercased() == NativeEditorDocumentCodec.fileExtension {
            try NativeEditorDocumentCodec.encode(document).write(to: url, options: .atomic)
            return
        }

        guard document.tabs.count == 1,
              let tab = document.tabs.first,
              EditorDocument.isLegacyCompatibleTabTitle(tab.title),
              (document.nextAutomaticTabNumber ?? EditorDocument.defaultNextAutomaticTabNumber)
                == EditorDocument.defaultNextAutomaticTabNumber else {
            throw DocumentFileStoreError.multipleTabsRequireNativeFormat
        }

        try writeDocument(tab.attributedString, to: url)
    }

    func readDocument(from url: URL) throws -> NSAttributedString {
        switch url.pathExtension.lowercased() {
        case "rtf", "docx", "odt":
            guard let documentType = attributedStringDocumentType(for: url) else {
                throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
            }

            return EditorTypography.normalizedAttributedString(
                try readAttributedString(from: url, documentType: documentType)
            )
        case "txt":
            let string = try readPlainText(from: url)
            return NSAttributedString(string: string, attributes: defaultTypingAttributes)
        default:
            throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
        }
    }

    func writeDocument(_ attributedString: NSAttributedString, to url: URL) throws {
        let normalizedDocument = EditorTypography.normalizedAttributedString(attributedString)

        switch url.pathExtension.lowercased() {
        case "rtf", "docx", "odt":
            guard let documentType = attributedStringDocumentType(for: url) else {
                throw DocumentFileStoreError.unsupportedFileType(url.pathExtension)
            }

            try writeRichText(normalizedDocument, to: url, documentType: documentType)
        case "txt":
            try normalizedDocument.string.write(to: url, atomically: true, encoding: .utf8)
        default:
            try writeRichText(normalizedDocument, to: url.appendingPathExtension("rtf"), documentType: .rtf)
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

    func normalizedEditorDocumentURL(_ url: URL) -> URL {
        let fileExtension = url.pathExtension.lowercased()

        if Self.supportedEditorDocumentFileExtensions.contains(fileExtension) {
            return url
        }

        return url.appendingPathExtension(NativeEditorDocumentCodec.fileExtension)
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
        let data = try Data(contentsOf: url)

        if let string = decodeBOMMarkedPlainText(data) {
            return string
        }

        if let string = String(data: data, encoding: .utf8) {
            return string
        }

        if let string = decodeLikelyUTF16PlainText(data) {
            return string
        }

        for encoding in Self.plainTextFallbackEncodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        throw DocumentFileStoreError.unreadableTextEncoding
    }

    private func decodeBOMMarkedPlainText(_ data: Data) -> String? {
        let bytes = Array(data.prefix(3))

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data, encoding: .utf8)
        }

        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }

        return nil
    }

    private func decodeLikelyUTF16PlainText(_ data: Data) -> String? {
        guard data.count >= 4 else { return nil }

        let sample = Array(data.prefix(min(data.count, 256)))
        let evenNulls = sample.enumerated().filter { index, byte in
            index.isMultiple(of: 2) && byte == 0
        }.count
        let oddNulls = sample.enumerated().filter { index, byte in
            !index.isMultiple(of: 2) && byte == 0
        }.count
        let threshold = max(2, sample.count / 8)

        if oddNulls > threshold && evenNulls == 0 {
            return String(data: data, encoding: .utf16LittleEndian)
        }

        if evenNulls > threshold && oddNulls == 0 {
            return String(data: data, encoding: .utf16BigEndian)
        }

        return nil
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
    case unreadableTextEncoding
    case multipleTabsRequireNativeFormat
    case invalidDocumentState

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let fileExtension):
            return "Unsupported file type: .\(fileExtension)"
        case .couldNotCreatePDF:
            return "Lite Text Editor could not create the PDF file."
        case .unreadableTextEncoding:
            return "Lite Text Editor could not determine the text encoding."
        case .multipleTabsRequireNativeFormat:
            return "Documents with tab names, multiple tabs, or preserved tab numbering must be saved as a .ltedoc file."
        case .invalidDocumentState:
            return "Lite Text Editor could not create a complete document snapshot."
        }
    }
}
