import XCTest
@testable import LiteTextEditor

final class EditorPreferencesTests: XCTestCase {
    func testWritingSettingsDefaultToHelpfulNativeEditorBehavior() {
        let defaults = isolatedUserDefaults()

        XCTAssertTrue(WritingSettingsStore.loadIsContinuousSpellCheckingEnabled(userDefaults: defaults))
        XCTAssertTrue(WritingSettingsStore.loadIsGrammarCheckingEnabled(userDefaults: defaults))
        XCTAssertFalse(WritingSettingsStore.loadIsAutomaticReplacementEnabled(userDefaults: defaults))
        XCTAssertTrue(WritingSettingsStore.loadIsAutomaticQuoteSubstitutionEnabled(userDefaults: defaults))
        XCTAssertTrue(WritingSettingsStore.loadIsAutomaticDashSubstitutionEnabled(userDefaults: defaults))
    }

    func testWritingSettingsPersistChoices() {
        let defaults = isolatedUserDefaults()

        WritingSettingsStore.saveIsContinuousSpellCheckingEnabled(false, userDefaults: defaults)
        WritingSettingsStore.saveIsGrammarCheckingEnabled(false, userDefaults: defaults)
        WritingSettingsStore.saveIsAutomaticReplacementEnabled(true, userDefaults: defaults)
        WritingSettingsStore.saveIsAutomaticQuoteSubstitutionEnabled(false, userDefaults: defaults)
        WritingSettingsStore.saveIsAutomaticDashSubstitutionEnabled(false, userDefaults: defaults)

        XCTAssertFalse(WritingSettingsStore.loadIsContinuousSpellCheckingEnabled(userDefaults: defaults))
        XCTAssertFalse(WritingSettingsStore.loadIsGrammarCheckingEnabled(userDefaults: defaults))
        XCTAssertTrue(WritingSettingsStore.loadIsAutomaticReplacementEnabled(userDefaults: defaults))
        XCTAssertFalse(WritingSettingsStore.loadIsAutomaticQuoteSubstitutionEnabled(userDefaults: defaults))
        XCTAssertFalse(WritingSettingsStore.loadIsAutomaticDashSubstitutionEnabled(userDefaults: defaults))
    }

    func testAutocompleteSettingsDefaultAndClampSuggestionWords() {
        let defaults = isolatedUserDefaults()

        XCTAssertTrue(AutocompleteSettingsStore.loadIsInlineSuggestionsEnabled(userDefaults: defaults))
        XCTAssertEqual(AutocompleteSettingsStore.loadMaxSuggestionWords(userDefaults: defaults), 4)

        AutocompleteSettingsStore.saveMaxSuggestionWords(1, userDefaults: defaults)
        XCTAssertEqual(AutocompleteSettingsStore.loadMaxSuggestionWords(userDefaults: defaults), 2)

        AutocompleteSettingsStore.saveMaxSuggestionWords(12, userDefaults: defaults)
        XCTAssertEqual(AutocompleteSettingsStore.loadMaxSuggestionWords(userDefaults: defaults), 5)
    }

    func testAutocompleteInlineSuggestionSettingPersistsChoices() {
        let defaults = isolatedUserDefaults()

        AutocompleteSettingsStore.saveIsInlineSuggestionsEnabled(false, userDefaults: defaults)

        XCTAssertFalse(AutocompleteSettingsStore.loadIsInlineSuggestionsEnabled(userDefaults: defaults))
    }

    func testStartupSettingsDefaultToReopenLastDocumentAndPersistChoices() {
        let defaults = isolatedUserDefaults()

        XCTAssertTrue(StartupSettingsStore.loadShouldReopenLastDocument(userDefaults: defaults))

        StartupSettingsStore.saveShouldReopenLastDocument(false, userDefaults: defaults)

        XCTAssertFalse(StartupSettingsStore.loadShouldReopenLastDocument(userDefaults: defaults))
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "LiteTextEditorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated user defaults")
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
