import SwiftUI

struct SpellingCorrectionCard: View {
    let state: SpellCorrectionState
    let onSelectSuggestion: (Int) -> Void
    let onApply: () -> Void
    let onIgnore: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Spelling")
                    .font(ChromeStyle.controlTextFont.weight(.semibold))
                    .foregroundStyle(ChromeStyle.controlTextColor)

                Spacer()

                Text("Enter to change")
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help("Close Spelling Review")
            }

            if state.hasIssue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.statusText)
                        .font(ChromeStyle.smallTextFont)
                        .foregroundStyle(ChromeStyle.secondaryTextColor)

                    Text(state.originalWord)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.bottom, 2)
                }

                VStack(alignment: .leading, spacing: 5) {
                    if state.suggestions.isEmpty {
                        Text("No suggestions")
                            .font(ChromeStyle.controlTextFont)
                            .foregroundStyle(ChromeStyle.secondaryTextColor)
                            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                    } else {
                        ForEach(Array(state.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                onSelectSuggestion(index)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(suggestion)
                                        .font(ChromeStyle.controlTextFont)
                                        .foregroundStyle(index == state.selectedSuggestionIndex ? Color.white : ChromeStyle.controlTextColor)
                                        .lineLimit(1)

                                    Spacer()

                                    if index == state.selectedSuggestionIndex {
                                        Image(systemName: "return")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 9)
                                .frame(height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(index == state.selectedSuggestionIndex ? Color.accentColor : Color(nsColor: .controlColor).opacity(0.24))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Use \(suggestion)")
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("Ignore") {
                        onIgnore()
                    }
                    .controlSize(.small)

                    Spacer()

                    Button(state.selectedSuggestion == nil ? "Next" : "Change") {
                        onApply()
                    }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Text(state.statusText)
                    .font(ChromeStyle.controlTextFont)
                    .foregroundStyle(ChromeStyle.controlTextColor)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                HStack {
                    Spacer()

                    Button("Done") {
                        onClose()
                    }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(12)
        .frame(width: 292)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
}
