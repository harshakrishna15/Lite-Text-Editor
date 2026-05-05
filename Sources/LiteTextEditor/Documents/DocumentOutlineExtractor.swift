import AppKit
import Foundation

struct DocumentOutlineExtractor {
    struct StructureSnapshot: Equatable {
        let items: [DocumentOutlineItem]
        let metadata: DocumentStructureMetadata
    }

    func makeOutlineItems(from attributedString: NSAttributedString) -> [DocumentOutlineItem] {
        makeStructureSnapshot(from: attributedString).items
    }

    func makeStructureSnapshot(from attributedString: NSAttributedString) -> StructureSnapshot {
        let string = attributedString.string as NSString
        guard string.length > 0 else {
            return StructureSnapshot(items: [], metadata: .empty)
        }

        let candidates = outlineCandidates(from: attributedString, string: string)
        guard !candidates.isEmpty else {
            return StructureSnapshot(items: [], metadata: .empty)
        }

        var items: [DocumentOutlineItem] = []
        var sectionCounters: [Int] = []

        for (index, candidate) in candidates.enumerated() {
            let sectionNumber = nextSectionNumber(for: candidate.level, counters: &sectionCounters)
            let sectionEnd = candidates[(index + 1)...].first { nextCandidate in
                nextCandidate.level <= candidate.level
            }?.location ?? string.length
            let sectionLength = max(0, sectionEnd - candidate.location)
            let sectionBodyRange = bodyRange(for: candidate, sectionEnd: sectionEnd, stringLength: string.length)
            let sectionMetrics = metrics(in: sectionBodyRange, string: string)
            let childCount = candidates[(index + 1)...].prefix { nextCandidate in
                nextCandidate.level > candidate.level
            }
            .count

            items.append(
                DocumentOutlineItem(
                    title: candidate.title,
                    level: candidate.level,
                    location: candidate.location,
                    headingLength: candidate.headingLength,
                    sectionEndLocation: sectionEnd,
                    sectionNumber: sectionNumber,
                    sectionLength: sectionLength,
                    headingWordCount: wordCount(in: candidate.title),
                    wordCount: sectionMetrics.wordCount,
                    characterCount: sectionMetrics.characterCount,
                    paragraphCount: sectionMetrics.paragraphCount,
                    childCount: childCount
                )
            )
        }

        return StructureSnapshot(items: items, metadata: makeMetadata(from: items))
    }

    private func outlineCandidates(from attributedString: NSAttributedString, string: NSString) -> [DocumentOutlineCandidate] {
        var candidates: [DocumentOutlineCandidate] = []
        var location = 0

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            defer {
                location = max(NSMaxRange(paragraphRange), location + 1)
            }

            guard paragraphRange.length > 0,
                  let headingLocation = firstNonWhitespaceLocation(in: paragraphRange, string: string),
                  headingLocation < attributedString.length else {
                continue
            }

            let paragraphText = string.substring(with: paragraphRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { continue }

            let attributes = attributedString.attributes(at: headingLocation, effectiveRange: nil)
            let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 11)
            guard let level = outlineLevel(for: font) else { continue }

            candidates.append(
                DocumentOutlineCandidate(
                    title: paragraphText,
                    level: level,
                    location: headingLocation,
                    headingLength: (paragraphText as NSString).length
                )
            )
        }

        return candidates
    }

    private func nextSectionNumber(for level: Int, counters: inout [Int]) -> String {
        guard level > 0 else {
            counters.removeAll(keepingCapacity: true)
            return ""
        }

        while counters.count < level {
            counters.append(0)
        }

        for parentIndex in 0..<(level - 1) where counters[parentIndex] == 0 {
            counters[parentIndex] = 1
        }

        counters[level - 1] += 1

        if counters.count > level {
            counters.removeSubrange(level..<counters.count)
        }

        return counters.prefix(level).map(String.init).joined(separator: ".")
    }

    private func bodyRange(for candidate: DocumentOutlineCandidate, sectionEnd: Int, stringLength: Int) -> NSRange {
        let bodyStart = min(candidate.location + candidate.headingLength, stringLength)
        let bodyEnd = min(sectionEnd, stringLength)
        return NSRange(location: bodyStart, length: max(0, bodyEnd - bodyStart))
    }

    private func wordCount(in text: String) -> Int {
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

    private func metrics(in range: NSRange, string: NSString) -> DocumentOutlineSectionMetrics {
        guard range.length > 0 else {
            return DocumentOutlineSectionMetrics(wordCount: 0, characterCount: 0, paragraphCount: 0)
        }

        return DocumentOutlineSectionMetrics(
            wordCount: wordCount(in: range, string: string),
            characterCount: characterCount(in: range, string: string),
            paragraphCount: paragraphCount(in: range, string: string)
        )
    }

    private func wordCount(in range: NSRange, string: NSString) -> Int {
        var count = 0
        string.enumerateSubstrings(
            in: range,
            options: [.byWords, .localized]
        ) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
        return count
    }

    private func paragraphCount(in range: NSRange, string: NSString) -> Int {
        var count = 0
        var currentLineHasContent = false
        let end = NSMaxRange(range)

        for index in range.location..<end {
            let character = string.character(at: index)
            guard let scalar = UnicodeScalar(character) else { continue }

            if CharacterSet.newlines.contains(scalar) {
                if currentLineHasContent {
                    count += 1
                }
                currentLineHasContent = false
            } else if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                currentLineHasContent = true
            }
        }

        if currentLineHasContent {
            count += 1
        }

        return count
    }

    private func characterCount(in range: NSRange, string: NSString) -> Int {
        var count = 0
        string.enumerateSubstrings(
            in: range,
            options: [.byComposedCharacterSequences]
        ) { substring, _, _, _ in
            guard let substring else { return }
            if !substring.allSatisfy({ $0.isDocumentStructureWhitespace }) {
                count += 1
            }
        }
        return count
    }

    private func makeMetadata(from items: [DocumentOutlineItem]) -> DocumentStructureMetadata {
        let titleItems = items.filter { $0.level == 0 }
        let sectionItems = items.filter { $0.level == 1 }
        let nestedItems = items.filter { $0.level > 1 }

        return DocumentStructureMetadata(
            title: titleItems.first?.title,
            titleCount: titleItems.count,
            sectionCount: sectionItems.count,
            subsectionCount: nestedItems.count,
            deepestLevel: items.map(\.level).max() ?? 0,
            totalHeadingWords: items.reduce(0) { $0 + $1.headingWordCount },
            totalSectionWords: items.reduce(0) { $0 + $1.wordCount }
        )
    }

    private func firstNonWhitespaceLocation(in range: NSRange, string: NSString) -> Int? {
        let end = NSMaxRange(range)
        guard range.location < end else { return nil }

        for index in range.location..<end {
            let character = string.character(at: index)
            guard let scalar = UnicodeScalar(character) else { continue }

            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return index
            }
        }

        return nil
    }

    private func outlineLevel(for font: NSFont) -> Int? {
        if font.pointSize >= TextPreset.title.size - 1 {
            return 0
        }

        if font.pointSize >= TextPreset.heading.size - 1 {
            return 1
        }

        if font.pointSize >= TextPreset.subheading.size - 1 {
            return 2
        }

        return nil
    }
}

private struct DocumentOutlineCandidate {
    let title: String
    let level: Int
    let location: Int
    let headingLength: Int
}

private struct DocumentOutlineSectionMetrics {
    let wordCount: Int
    let characterCount: Int
    let paragraphCount: Int
}

private extension Character {
    var isDocumentStructureWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
