import Foundation

typealias LocalModelDownloadProgressHandler = (LocalModelDownloadProgress) -> Void

enum LocalModelDownloadLocation {
    static var defaultDirectoryURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return applicationSupport
            .appendingPathComponent("Lite Text Editor", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Files", isDirectory: true)
    }
}

struct LocalModelDownloadProgress: Equatable {
    let bytesDownloaded: Int64
    let totalBytes: Int64?
    let estimatedSecondsRemaining: TimeInterval?

    var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(bytesDownloaded) / Double(totalBytes), 0), 1)
    }

    var percentageText: String? {
        guard let fractionCompleted else { return nil }
        return "\(Int((fractionCompleted * 100).rounded()))%"
    }

    var statusText: String {
        if let percentageText {
            if let estimatedTimeText {
                return "Downloading... \(percentageText) - \(estimatedTimeText)"
            }

            return "Downloading... \(percentageText) - estimating time"
        }

        return "Downloading... \(downloadedBytesText)"
    }

    private var estimatedTimeText: String? {
        guard let estimatedSecondsRemaining else { return nil }
        guard estimatedSecondsRemaining > 0 else { return "finishing" }

        let seconds = max(1, Int(estimatedSecondsRemaining.rounded(.up)))

        if seconds < 60 {
            return "about \(seconds)s left"
        }

        let minutes = Int((Double(seconds) / 60).rounded(.up))
        if minutes < 60 {
            return "about \(minutes)m left"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "about \(hours)h left"
        }

        return "about \(hours)h \(remainingMinutes)m left"
    }

    private var downloadedBytesText: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }
}

protocol LocalModelTextGenerating: AnyObject {
    var modelName: String { get }
    var isLoaded: Bool { get }
    var modelDownloadDirectoryURL: URL { get }
    func load() async throws
    func isDownloaded() async throws -> Bool
    func download(progressHandler: LocalModelDownloadProgressHandler?) async throws
    func uninstall() async throws
    func completion(for prompt: String) -> String?
}

extension LocalModelTextGenerating {
    var modelName: String { "Local Model" }
    var modelDownloadDirectoryURL: URL { LocalModelDownloadLocation.defaultDirectoryURL }

    func download() async throws {
        try await download(progressHandler: nil)
    }

    func download(progressHandler: LocalModelDownloadProgressHandler?) async throws {
        try await load()
    }

    func isDownloaded() async throws -> Bool {
        isLoaded
    }

    func uninstall() async throws {}
}

final class UnavailableLocalModelTextGenerator: LocalModelTextGenerating {
    var isLoaded: Bool { false }

    func load() async throws {}

    func completion(for prompt: String) -> String? {
        nil
    }
}

struct LocalModelSuggestionPostProcessor {
    func suggestion(from rawCompletion: String, request: SuggestionRequest) -> String? {
        let cleaned = clean(rawCompletion)
        guard !cleaned.isEmpty else { return nil }

        let suffixOnly = removingRepeatedPrefix(from: cleaned, request: request)
        let words = suffixOnly
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard words.count >= 2 else { return nil }

        let clipped = words
            .prefix(request.maxWords)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !repeatsRecentPrefix(clipped, request: request) else { return nil }

        return clipped.isEmpty ? nil : clipped
    }

    private func clean(_ rawCompletion: String) -> String {
        let firstLine = rawCompletion
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""

        let unwrapped = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return strippingInstructionalWrapper(from: strippingKnownLabel(from: unwrapped))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func strippingKnownLabel(from text: String) -> String {
        let labels = [
            "Completion:",
            "Suggestion:",
            "Answer:",
            "Prediction:",
            "Autocomplete:"
        ]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercased = trimmed.lowercased()

        for label in labels where lowercased.hasPrefix(label.lowercased()) {
            return String(trimmed.dropFirst(label.count))
        }

        return trimmed
    }

    private func strippingInstructionalWrapper(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let wrappers = [
            "the next words are",
            "the next words would be",
            "the continuation is",
            "a natural continuation is",
            "i would continue with",
            "continue with",
            "insert",
            "answer:"
        ]

        for wrapper in wrappers where lowercased.hasPrefix(wrapper) {
            let remainder = String(trimmed.dropFirst(wrapper.count))
            return remainder
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":,- "))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private func removingRepeatedPrefix(from completion: String, request: SuggestionRequest) -> String {
        let prefixWords = request.prefixContext
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !prefixWords.isEmpty else { return completion }

        let completionWords = completion
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !completionWords.isEmpty else { return completion }

        for triggerLength in stride(from: min(prefixWords.count, completionWords.count), through: 1, by: -1) {
            let prefixTail = prefixWords.suffix(triggerLength).map(normalizedWord)
            let completionHead = completionWords.prefix(triggerLength).map(normalizedWord)

            if prefixTail == completionHead {
                return completionWords.dropFirst(triggerLength).joined(separator: " ")
            }
        }

        return completion
    }

    private func repeatsRecentPrefix(_ suggestion: String, request: SuggestionRequest) -> Bool {
        let prefixWords = request.prefixContext
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map(normalizedWord)
        let suggestionWords = suggestion
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map(normalizedWord)
        let maximumLength = min(prefixWords.count, suggestionWords.count)
        guard maximumLength >= 2 else { return false }

        for length in stride(from: maximumLength, through: 2, by: -1) {
            if Array(prefixWords.suffix(length)) == Array(suggestionWords.prefix(length)) {
                return true
            }
        }

        return false
    }

    private func normalizedWord(_ word: String) -> String {
        word
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
    }
}
