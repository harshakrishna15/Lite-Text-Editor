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

    let localModelState: LocalModelState
    let suggestionWordOptions: [String]
    let onRefreshLocalModelState: () -> Void
    let onDownloadLocalModel: () -> Void
    let onCancelLocalModelDownload: () -> Void
    let onUninstallLocalModel: () -> Void
    let onShowLocalModelDownloadLocation: () -> Void
    let onSuggestionWordsCommit: (String) -> Void

    var body: some View {
        let isAutocompleteEnabled = localModelState.isLoaded
        let areSuggestionControlsEnabled = isAutocompleteEnabled && isInlineSuggestionsEnabled

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

                        HStack(alignment: .top, spacing: 14) {
                            Text("Model")
                                .font(ChromeStyle.controlTextFont)
                                .foregroundStyle(ChromeStyle.controlTextColor)
                                .frame(width: 178, alignment: .leading)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(localModelState.modelName)
                                    .font(ChromeStyle.controlTextFont)
                                    .foregroundStyle(ChromeStyle.controlTextColor)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(localModelState.statusText)
                                    .font(ChromeStyle.smallTextFont)
                                    .foregroundStyle(localModelState.isLoaded ? ChromeStyle.secondaryTextColor : .secondary)
                                    .lineLimit(1)

                                if localModelState.isDownloading {
                                    if let fractionCompleted = localModelState.downloadProgress?.fractionCompleted {
                                        ProgressView(value: fractionCompleted, total: 1)
                                            .frame(maxWidth: 220)
                                    } else {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .trailing, spacing: 8) {
                                HStack(spacing: 10) {
                                    Button(localModelState.primaryActionTitle) {
                                        if localModelState.isDownloading {
                                            onCancelLocalModelDownload()
                                        } else if localModelState.isLoaded {
                                            onRefreshLocalModelState()
                                        } else {
                                            onDownloadLocalModel()
                                        }
                                    }
                                    .disabled(localModelState.isBusy && !localModelState.isDownloading)
                                    .help(localModelState.primaryActionTitle)

                                    if localModelState.canUninstall {
                                        Button("Uninstall") {
                                            onUninstallLocalModel()
                                        }
                                        .disabled(localModelState.isBusy)
                                        .help("Uninstall Model")
                                    }
                                }

                                Button("Show in Finder") {
                                    onShowLocalModelDownloadLocation()
                                }
                                .help("Show Model Download Location")
                            }
                        }

                        settingsToggle(
                            "Show inline suggestions",
                            isOn: $isInlineSuggestionsEnabled,
                            help: "Show Inline Suggestions"
                        )
                        .disabled(!isAutocompleteEnabled)
                        .opacity(isAutocompleteEnabled ? 1 : 0.45)

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

                    Divider()

                    licenseSection
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
        .onAppear(perform: onRefreshLocalModelState)
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>, help: String) -> some View {
        Toggle(title, isOn: isOn)
            .font(ChromeStyle.controlTextFont)
            .toggleStyle(.checkbox)
            .help(help)
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Licenses")
                .font(ChromeStyle.controlTextFont)
                .foregroundStyle(ChromeStyle.controlTextColor)

            ForEach(LicenseAcknowledgements.all) { acknowledgement in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 9) {
                        Link("Source", destination: acknowledgement.sourceURL)
                            .font(ChromeStyle.smallTextFont)

                        Text(acknowledgement.licenseText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ChromeStyle.controlTextColor)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.72))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ChromeStyle.chromeControlBorder, lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(acknowledgement.name)
                            .font(ChromeStyle.controlTextFont)
                            .foregroundStyle(ChromeStyle.controlTextColor)

                        Text("\(acknowledgement.licenseName) - \(acknowledgement.usage)")
                            .font(ChromeStyle.smallTextFont)
                            .foregroundStyle(ChromeStyle.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(ChromeStyle.controlTextFont)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ChromeStyle.chromeControlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ChromeStyle.chromeControlBorder, lineWidth: 1)
                )
            }
        }
    }
}
