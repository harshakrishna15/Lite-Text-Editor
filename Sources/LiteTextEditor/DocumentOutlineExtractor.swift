import AppKit
import Foundation

struct DocumentOutlineExtractor {
    func makeOutlineItems(from attributedString: NSAttributedString) -> [DocumentOutlineItem] {
        let string = attributedString.string as NSString
        guard string.length > 0 else { return [] }

        let candidates = outlineCandidates(from: attributedString, string: string)
        guard !candidates.isEmpty else { return [] }

        var items: [DocumentOutlineItem] = []
        var sectionCounters = (headings: 0, subheadings: 0)

        for (index, candidate) in candidates.enumerated() {
            let sectionNumber = nextSectionNumber(for: candidate.level, counters: &sectionCounters)
            let sectionEnd = candidates[(index + 1)...].first { nextCandidate in
                nextCandidate.level <= candidate.level
            }?.location ?? string.length
            let sectionLength = max(0, sectionEnd - candidate.location)
            let sectionRange = NSRange(location: candidate.location, length: sectionLength)
            let sectionText = string.substring(with: sectionRange)
            let childCount = candidates[(index + 1)...].prefix { nextCandidate in
                nextCandidate.level > candidate.level
            }
            .count

            items.append(
                DocumentOutlineItem(
                    title: candidate.title,
                    level: candidate.level,
                    location: candidate.location,
                    sectionNumber: sectionNumber,
                    sectionLength: sectionLength,
                    wordCount: wordCount(in: sectionText),
                    paragraphCount: paragraphCount(in: sectionText),
                    childCount: childCount
                )
            )
        }

        return items
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
                    location: headingLocation
                )
            )
        }

        return candidates
    }

    private func nextSectionNumber(for level: Int, counters: inout (headings: Int, subheadings: Int)) -> String {
        switch level {
        case 0:
            return ""
        case 1:
            counters.headings += 1
            counters.subheadings = 0
            return "\(counters.headings)"
        default:
            if counters.headings == 0 {
                counters.headings = 1
            }
            counters.subheadings += 1
            return "\(counters.headings).\(counters.subheadings)"
        }
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

    private func paragraphCount(in text: String) -> Int {
        text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
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
}
