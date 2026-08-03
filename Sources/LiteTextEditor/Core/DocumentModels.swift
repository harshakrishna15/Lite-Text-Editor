import AppKit
import Foundation

enum DocumentCountMetric: String, CaseIterable, Identifiable {
    case words
    case characters
    case charactersNoSpaces
    case sentences
    case paragraphs
    case lines
    case pages
    case readingTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .words:
            return "Words"
        case .characters:
            return "Characters"
        case .charactersNoSpaces:
            return "Characters No Spaces"
        case .sentences:
            return "Sentences"
        case .paragraphs:
            return "Paragraphs"
        case .lines:
            return "Lines"
        case .pages:
            return "Pages"
        case .readingTime:
            return "Reading Time"
        }
    }

    var shortTitle: String {
        switch self {
        case .characters:
            return "Chars"
        case .charactersNoSpaces:
            return "Chars No Spaces"
        case .readingTime:
            return "Reading"
        default:
            return title
        }
    }

    func statusText(for statistics: DocumentTextStatistics) -> String {
        "\(shortTitle): \(valueText(for: statistics))"
    }

    func menuText(for statistics: DocumentTextStatistics) -> String {
        "\(title): \(valueText(for: statistics))"
    }

    private func valueText(for statistics: DocumentTextStatistics) -> String {
        switch self {
        case .words:
            return DocumentTextStatistics.formatted(statistics.words)
        case .characters:
            return DocumentTextStatistics.formatted(statistics.characters)
        case .charactersNoSpaces:
            return DocumentTextStatistics.formatted(statistics.charactersNoSpaces)
        case .sentences:
            return DocumentTextStatistics.formatted(statistics.sentences)
        case .paragraphs:
            return DocumentTextStatistics.formatted(statistics.paragraphs)
        case .lines:
            return DocumentTextStatistics.formatted(statistics.lines)
        case .pages:
            return DocumentTextStatistics.formatted(statistics.pages)
        case .readingTime:
            return statistics.readingTimeText
        }
    }
}

struct DocumentTextStatistics: Equatable {
    let words: Int
    let characters: Int
    let charactersNoSpaces: Int
    let sentences: Int
    let paragraphs: Int
    let lines: Int
    let pages: Int
    let estimatedReadingMinutes: Int

    static let empty = DocumentTextStatistics(
        words: 0,
        characters: 0,
        charactersNoSpaces: 0,
        sentences: 0,
        paragraphs: 0,
        lines: 0,
        pages: 1,
        estimatedReadingMinutes: 0
    )

    var readingTimeText: String {
        guard words > 0 else { return "0 min" }
        return words < 225 ? "<1 min" : "\(estimatedReadingMinutes) min"
    }

    static func make(from text: String, pages: Int) -> DocumentTextStatistics {
        let words = countSubstrings(in: text, by: .byWords)
        let sentences = countSubstrings(in: text, by: .bySentences)
        let lineCounts = lineAndParagraphCounts(in: text)
        let characterCounts = characterCounts(in: text)
        let readingMinutes = words == 0 ? 0 : max(1, Int(ceil(Double(words) / 225.0)))

        return DocumentTextStatistics(
            words: words,
            characters: characterCounts.total,
            charactersNoSpaces: characterCounts.nonWhitespace,
            sentences: sentences,
            paragraphs: lineCounts.paragraphs,
            lines: lineCounts.lines,
            pages: max(1, pages),
            estimatedReadingMinutes: readingMinutes
        )
    }

    static func formatted(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func countSubstrings(in text: String, by granularity: String.EnumerationOptions) -> Int {
        var count = 0
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [granularity, .localized]
        ) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
        return count
    }

    private static func lineAndParagraphCounts(in text: String) -> (lines: Int, paragraphs: Int) {
        guard !text.isEmpty else { return (lines: 0, paragraphs: 0) }

        var lines = 1
        var paragraphs = 0
        var currentLineHasContent = false

        for scalar in text.unicodeScalars {
            if CharacterSet.newlines.contains(scalar) {
                if currentLineHasContent {
                    paragraphs += 1
                }
                currentLineHasContent = false
                lines += 1
            } else if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                currentLineHasContent = true
            }
        }

        if currentLineHasContent {
            paragraphs += 1
        }

        return (lines: lines, paragraphs: paragraphs)
    }

    private static func characterCounts(in text: String) -> (total: Int, nonWhitespace: Int) {
        var total = 0
        var nonWhitespace = 0

        for character in text {
            total += 1
            if !character.isDocumentWhitespace {
                nonWhitespace += 1
            }
        }

        return (total, nonWhitespace)
    }
}

struct SpellCorrectionState: Equatable {
    var isPresented: Bool
    var issueRange: NSRange?
    var originalWord: String
    var suggestions: [String]
    var selectedSuggestionIndex: Int
    var statusText: String

    static let inactive = SpellCorrectionState(
        isPresented: false,
        issueRange: nil,
        originalWord: "",
        suggestions: [],
        selectedSuggestionIndex: 0,
        statusText: ""
    )

    static let complete = SpellCorrectionState(
        isPresented: true,
        issueRange: nil,
        originalWord: "",
        suggestions: [],
        selectedSuggestionIndex: 0,
        statusText: "No spelling issues found."
    )

    var selectedSuggestion: String? {
        guard suggestions.indices.contains(selectedSuggestionIndex) else { return nil }
        return suggestions[selectedSuggestionIndex]
    }

    var hasIssue: Bool {
        issueRange != nil
    }
}

enum PredictionState: Equatable {
    case idle
    case predicting
    case available(wordCount: Int)

    static func available(for suggestion: String) -> PredictionState {
        let wordCount = suggestion
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return .available(wordCount: wordCount)
    }

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case .predicting:
            return "Predicting..."
        case .available(let wordCount):
            let clampedWordCount = max(1, wordCount)
            return "Prediction: \(clampedWordCount) \(clampedWordCount == 1 ? "word" : "words")"
        }
    }
}

struct DocumentStructureMetadata: Equatable {
    let title: String?
    let titleCount: Int
    let sectionCount: Int
    let subsectionCount: Int
    let deepestLevel: Int
    let totalHeadingWords: Int
    let totalSectionWords: Int

    static let empty = DocumentStructureMetadata(
        title: nil,
        titleCount: 0,
        sectionCount: 0,
        subsectionCount: 0,
        deepestLevel: 0,
        totalHeadingWords: 0,
        totalSectionWords: 0
    )

    var hasStructure: Bool {
        titleCount > 0 || sectionCount > 0 || subsectionCount > 0
    }

    var displayTitle: String {
        title ?? "Untitled document"
    }

    var summaryText: String {
        guard hasStructure else { return "No headings" }

        var parts: [String] = []
        if sectionCount > 0 {
            parts.append("\(sectionCount) \(sectionCount == 1 ? "section" : "sections")")
        }

        if subsectionCount > 0 {
            parts.append("\(subsectionCount) nested")
        }

        if totalSectionWords > 0 {
            parts.append("\(DocumentTextStatistics.formatted(totalSectionWords)) words")
        }

        return parts.isEmpty ? "\(titleCount) \(titleCount == 1 ? "title" : "titles")" : parts.joined(separator: " - ")
    }
}

struct DocumentOutlineItem: Identifiable, Equatable {
    let title: String
    let level: Int
    let location: Int
    let headingLength: Int
    let sectionEndLocation: Int
    let sectionNumber: String
    let sectionLength: Int
    let headingWordCount: Int
    let wordCount: Int
    let characterCount: Int
    let paragraphCount: Int
    let childCount: Int

    var id: String {
        "\(location)-\(level)-\(sectionNumber)-\(title)"
    }

    var levelTitle: String {
        switch level {
        case 0:
            return "Title"
        case 1:
            return "Heading"
        default:
            return "Subheading"
        }
    }

    var displayTitle: String {
        sectionNumber.isEmpty ? title : "\(sectionNumber) \(title)"
    }

    var detailText: String {
        var parts = [levelTitle]

        if wordCount > 0 {
            parts.append("\(wordCount) \(wordCount == 1 ? "word" : "words")")
        }

        if childCount > 0 {
            parts.append("\(childCount) nested")
        } else if paragraphCount > 1 {
            parts.append("\(paragraphCount) paragraphs")
        }

        return parts.joined(separator: " - ")
    }

    var range: NSRange {
        NSRange(location: location, length: headingLength)
    }

    var sectionRange: NSRange {
        NSRange(location: location, length: sectionLength)
    }

    var metadataText: String {
        let words = wordCount > 0 ? "\(DocumentTextStatistics.formatted(wordCount)) words" : "No body text"
        let characters = characterCount > 0 ? "\(DocumentTextStatistics.formatted(characterCount)) chars" : nil
        return [words, characters].compactMap { $0 }.joined(separator: " - ")
    }
}

struct FormattingState: Equatable {
    var fontFamilyName = "Courier"
    var fontSize = 12.0
    var textColor = NSColor.black
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isStrikethrough = false
    var highlightColor: NSColor?
    var hasHighlight: Bool { highlightColor != nil }
    var isBulletedList = false
    var isNumberedList = false
    var alignment: NSTextAlignment = .left
}

private extension Character {
    var isDocumentWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
