import Foundation

enum LastDocumentStore {
    private static let lastDocumentURLKey = "LiteTextEditor.lastDocumentURL"

    static var lastDocumentURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: lastDocumentURLKey),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    static func saveLastDocumentURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastDocumentURLKey)
    }

    static func clearLastDocumentURL() {
        UserDefaults.standard.removeObject(forKey: lastDocumentURLKey)
    }
}

enum WritingSettingsStore {
    private static let isContinuousSpellCheckingEnabledKey = "LiteTextEditor.continuousSpellCheckingEnabled"
    private static let isGrammarCheckingEnabledKey = "LiteTextEditor.grammarCheckingEnabled"
    private static let isAutomaticReplacementEnabledKey = "LiteTextEditor.automaticTextReplacementEnabled"
    private static let isAutomaticQuoteSubstitutionEnabledKey = "LiteTextEditor.automaticQuoteSubstitutionEnabled"
    private static let isAutomaticDashSubstitutionEnabledKey = "LiteTextEditor.automaticDashSubstitutionEnabled"

    static func loadIsContinuousSpellCheckingEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        loadBool(forKey: isContinuousSpellCheckingEnabledKey, defaultValue: true, userDefaults: userDefaults)
    }

    static func saveIsContinuousSpellCheckingEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isContinuousSpellCheckingEnabledKey)
    }

    static func loadIsGrammarCheckingEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        loadBool(forKey: isGrammarCheckingEnabledKey, defaultValue: true, userDefaults: userDefaults)
    }

    static func saveIsGrammarCheckingEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isGrammarCheckingEnabledKey)
    }

    static func loadIsAutomaticReplacementEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        loadBool(forKey: isAutomaticReplacementEnabledKey, defaultValue: false, userDefaults: userDefaults)
    }

    static func saveIsAutomaticReplacementEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isAutomaticReplacementEnabledKey)
    }

    static func loadIsAutomaticQuoteSubstitutionEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        loadBool(forKey: isAutomaticQuoteSubstitutionEnabledKey, defaultValue: true, userDefaults: userDefaults)
    }

    static func saveIsAutomaticQuoteSubstitutionEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isAutomaticQuoteSubstitutionEnabledKey)
    }

    static func loadIsAutomaticDashSubstitutionEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        loadBool(forKey: isAutomaticDashSubstitutionEnabledKey, defaultValue: true, userDefaults: userDefaults)
    }

    static func saveIsAutomaticDashSubstitutionEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isAutomaticDashSubstitutionEnabledKey)
    }

    private static func loadBool(forKey key: String, defaultValue: Bool, userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return userDefaults.bool(forKey: key)
    }
}

enum AutocompleteSettingsStore {
    static let minimumSuggestionWords = 2
    static let maximumSuggestionWords = 5
    static let defaultSuggestionWords = 4

    private static let isInlineSuggestionsEnabledKey = "LiteTextEditor.inlineSuggestionsEnabled"
    private static let maxSuggestionWordsKey = "LiteTextEditor.maxSuggestionWords"

    static func loadIsInlineSuggestionsEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        guard userDefaults.object(forKey: isInlineSuggestionsEnabledKey) != nil else {
            return true
        }

        return userDefaults.bool(forKey: isInlineSuggestionsEnabledKey)
    }

    static func saveIsInlineSuggestionsEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: isInlineSuggestionsEnabledKey)
    }

    static func loadMaxSuggestionWords(userDefaults: UserDefaults = .standard) -> Int {
        guard userDefaults.object(forKey: maxSuggestionWordsKey) != nil else {
            return defaultSuggestionWords
        }

        return normalizedSuggestionWordCount(userDefaults.integer(forKey: maxSuggestionWordsKey))
    }

    static func saveMaxSuggestionWords(_ wordCount: Int, userDefaults: UserDefaults = .standard) {
        userDefaults.set(normalizedSuggestionWordCount(wordCount), forKey: maxSuggestionWordsKey)
    }

    static func normalizedSuggestionWordCount(_ wordCount: Int) -> Int {
        min(max(wordCount, minimumSuggestionWords), maximumSuggestionWords)
    }
}

enum StartupSettingsStore {
    private static let shouldReopenLastDocumentKey = "LiteTextEditor.reopenLastDocument"

    static func loadShouldReopenLastDocument(userDefaults: UserDefaults = .standard) -> Bool {
        guard userDefaults.object(forKey: shouldReopenLastDocumentKey) != nil else {
            return true
        }

        return userDefaults.bool(forKey: shouldReopenLastDocumentKey)
    }

    static func saveShouldReopenLastDocument(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: shouldReopenLastDocumentKey)
    }
}

struct RecentDocumentStore {
    static let maximumDocumentCount = 10

    private static let recentDocumentURLsKey = "LiteTextEditor.recentDocumentURLs"

    private let userDefaults: UserDefaults
    private let maximumCount: Int

    init(userDefaults: UserDefaults = .standard, maximumCount: Int = Self.maximumDocumentCount) {
        self.userDefaults = userDefaults
        self.maximumCount = maximumCount
    }

    func load() -> [URL] {
        guard let paths = userDefaults.array(forKey: Self.recentDocumentURLsKey) as? [String] else {
            return []
        }

        var seenPaths = Set<String>()
        return paths.compactMap { path in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else { return nil }

            let url = URL(fileURLWithPath: trimmedPath).standardizedFileURL
            guard seenPaths.insert(url.path).inserted else { return nil }
            return url
        }
    }

    func note(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        let remainingURLs = load().filter { $0.path != standardizedURL.path }
        save(Array(([standardizedURL] + remainingURLs).prefix(maximumCount)))
    }

    func remove(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        save(load().filter { $0.path != standardizedURL.path })
    }

    func clear() {
        userDefaults.removeObject(forKey: Self.recentDocumentURLsKey)
    }

    private func save(_ urls: [URL]) {
        userDefaults.set(urls.map(\.path), forKey: Self.recentDocumentURLsKey)
    }
}
