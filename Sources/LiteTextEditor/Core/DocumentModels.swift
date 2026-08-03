import Foundation

struct DocumentTextStatistics: Equatable {
    let words: Int
    let pages: Int

    static let empty = DocumentTextStatistics(
        words: 0,
        pages: 1
    )

    static func make(from text: String, pages: Int) -> DocumentTextStatistics {
        return DocumentTextStatistics(
            words: countWords(in: text),
            pages: max(1, pages)
        )
    }

    static func formatted(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func countWords(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byWords, .localized]
        ) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
        return count
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
    let totalSectionWords: Int

    static let empty = DocumentStructureMetadata(
        title: nil,
        titleCount: 0,
        sectionCount: 0,
        subsectionCount: 0,
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
    let sectionNumber: String
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

    var metadataText: String {
        let words = wordCount > 0 ? "\(DocumentTextStatistics.formatted(wordCount)) words" : "No body text"
        let characters = characterCount > 0 ? "\(DocumentTextStatistics.formatted(characterCount)) chars" : nil
        return [words, characters].compactMap { $0 }.joined(separator: " - ")
    }
}

struct FormattingState: Equatable {
    var fontSize = 12.0
    var isBold = false
    var isItalic = false
    var isUnderline = false
}
