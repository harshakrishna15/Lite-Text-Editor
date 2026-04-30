import SwiftUI

struct LiteTextEditorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAutosaveEnabled: Bool
    @Binding var suggestionWordsText: String

    let suggestionWordOptions: [String]
    let onSuggestionWordsCommit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Documents")
                    .font(ChromeStyle.controlTextFont)
                    .foregroundStyle(ChromeStyle.controlTextColor)

                Toggle("Autosave saved documents", isOn: $isAutosaveEnabled)
                    .font(ChromeStyle.controlTextFont)
                    .toggleStyle(.checkbox)
                    .help("Autosave runs only after a document has been opened or saved somewhere.")

                Text("Unsaved documents still require manual Save or Save As.")
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Autocomplete")
                    .font(ChromeStyle.controlTextFont)
                    .foregroundStyle(ChromeStyle.controlTextColor)

                HStack(spacing: 10) {
                    Text("Words per suggestion")
                        .font(ChromeStyle.controlTextFont)
                        .foregroundStyle(ChromeStyle.controlTextColor)
                        .frame(width: 160, alignment: .leading)

                    EditableComboBox(
                        text: $suggestionWordsText,
                        items: suggestionWordOptions,
                        visibleItemCount: suggestionWordOptions.count,
                        onCommit: onSuggestionWordsCommit
                    )
                    .frame(width: 92, height: ChromeStyle.toolbarControlHeight)
                    .help("Words per Suggestion")

                    Text("words")
                        .font(ChromeStyle.smallTextFont)
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                }

                Text("Choose a value from 2 to 5. Typed values are rounded and clamped into that range.")
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        .padding(20)
        .frame(width: 440)
    }
}
