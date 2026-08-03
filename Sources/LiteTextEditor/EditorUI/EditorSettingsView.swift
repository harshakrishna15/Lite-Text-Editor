import SwiftUI

struct LiteTextEditorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isContinuousSpellCheckingEnabled: Bool
    @Binding var isGrammarCheckingEnabled: Bool
    @Binding var isAutomaticTextReplacementEnabled: Bool
    @Binding var isAutomaticQuoteSubstitutionEnabled: Bool
    @Binding var isAutomaticDashSubstitutionEnabled: Bool
    @Binding var isInlineSuggestionsEnabled: Bool
    @Binding var shouldReopenLastDocument: Bool
    @Binding var suggestionWordsText: String

    let suggestionWordOptions: [String]
    let onSuggestionWordsCommit: (String) -> Void

    var body: some View {
        let areSuggestionControlsEnabled = isInlineSuggestionsEnabled

        VStack(alignment: .leading, spacing: 22) {
            Text("Settings")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Writing")
                            .font(ChromeStyle.controlTextFont)
                            .foregroundStyle(ChromeStyle.controlTextColor)

                        settingsToggle(
                            "Check spelling while typing",
                            isOn: $isContinuousSpellCheckingEnabled,
                            help: "Check Spelling While Typing"
                        )

                        settingsToggle(
                            "Automatically replace misspellings",
                            isOn: $isAutomaticTextReplacementEnabled,
                            help: "Automatically Replace Misspellings"
                        )

                        settingsToggle(
                            "Check grammar",
                            isOn: $isGrammarCheckingEnabled,
                            help: "Check Grammar"
                        )

                        settingsToggle(
                            "Use smart quotes",
                            isOn: $isAutomaticQuoteSubstitutionEnabled,
                            help: "Use Smart Quotes"
                        )

                        settingsToggle(
                            "Use smart dashes",
                            isOn: $isAutomaticDashSubstitutionEnabled,
                            help: "Use Smart Dashes"
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Autocomplete")
                            .font(ChromeStyle.controlTextFont)
                            .foregroundStyle(ChromeStyle.controlTextColor)

                        settingsToggle(
                            "Show inline suggestions",
                            isOn: $isInlineSuggestionsEnabled,
                            help: "Show Inline Suggestions"
                        )

                        HStack(spacing: 14) {
                            Text("Words per suggestion")
                                .font(ChromeStyle.controlTextFont)
                                .foregroundStyle(areSuggestionControlsEnabled ? ChromeStyle.controlTextColor : ChromeStyle.secondaryTextColor)
                                .frame(width: 178, alignment: .leading)

                            EditableComboBox(
                                text: $suggestionWordsText,
                                items: suggestionWordOptions,
                                visibleItemCount: suggestionWordOptions.count,
                                onCommit: onSuggestionWordsCommit
                            )
                            .frame(width: 92, height: ChromeStyle.toolbarControlHeight)
                            .disabled(!areSuggestionControlsEnabled)
                            .help("Words per Suggestion")

                            Text("words")
                                .font(ChromeStyle.smallTextFont)
                                .foregroundStyle(ChromeStyle.secondaryTextColor)
                        }
                        .opacity(areSuggestionControlsEnabled ? 1 : 0.45)

                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Startup")
                            .font(ChromeStyle.controlTextFont)
                            .foregroundStyle(ChromeStyle.controlTextColor)

                        settingsToggle(
                            "Reopen last document on launch",
                            isOn: $shouldReopenLastDocument,
                            help: "Reopen Last Document on Launch"
                        )
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(maxHeight: 560)

            HStack {
                Spacer()

                Button("Done") {
                    onSuggestionWordsCommit(suggestionWordsText)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Done")
                .help("Done")
            }
        }
        .padding(30)
        .frame(width: 680)
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>, help: String) -> some View {
        Toggle(title, isOn: isOn)
            .font(ChromeStyle.controlTextFont)
            .toggleStyle(.checkbox)
            .help(help)
    }

}
