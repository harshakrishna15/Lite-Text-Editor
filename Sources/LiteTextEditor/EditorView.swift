import AppKit
import SwiftUI

struct EditorView: View {
    @StateObject private var editor: EditorController
    @State private var selectedFont = "System"
    @State private var selectedSize = 11.0
    @State private var selectedSizeText = "11"
    @State private var selectedStyle = TextPreset.body
    @State private var textColor = Color.black
    @State private var customTextColors = TextColorPaletteStore.load()
    @State private var suggestionWords = 4.0
    @State private var suggestionWordsText = "4"
    @State private var isSettingsPresented = false
    @State private var selectedCountMetric = DocumentCountMetric.words
    @State private var isOutlineVisible = false
    private let suggestionWordOptions = ["2", "3", "4", "5"]

    init(editor: EditorController = EditorController()) {
        _editor = StateObject(wrappedValue: editor)
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorFormattingToolbarView(
                editor: editor,
                selectedFont: $selectedFont,
                selectedSize: $selectedSize,
                selectedSizeText: $selectedSizeText,
                selectedStyle: $selectedStyle,
                textColor: $textColor,
                customTextColors: $customTextColors,
                isOutlineVisible: $isOutlineVisible
            )

            Divider()

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topTrailing) {
                    RichTextEditor(
                        controller: editor,
                        maxSuggestionWords: Int(suggestionWords)
                    )

                    if editor.spellCorrectionState.isPresented {
                        SpellingCorrectionCard(
                            state: editor.spellCorrectionState,
                            onSelectSuggestion: editor.selectSpellingSuggestion,
                            onApply: editor.applyCurrentSpellingCorrection,
                            onIgnore: editor.ignoreCurrentSpellingIssue,
                            onClose: editor.closeSpellingReview
                        )
                        .padding(.top, 14)
                        .padding(.trailing, 18)
                    }
                }
                .clipped()
                .background(Color(nsColor: .liteTextEditorDesk))

                GeometryReader { proxy in
                    if isOutlineVisible {
                        let panelHeight = outlinePanelHeight(for: proxy.size.height)

                        if panelHeight > 0 {
                            OutlineSidebarView(
                                items: editor.outlineItems,
                                activeItemID: editor.activeOutlineItemID,
                                summaryText: editor.outlineSummaryText,
                                metadata: editor.documentStructureMetadata,
                                height: panelHeight,
                                onSelect: editor.selectOutlineItem
                            ) {
                                withAnimation(ChromeStyle.outlinePanelAnimation) {
                                    isOutlineVisible = false
                                }
                            }
                                .padding(.leading, ChromeStyle.outlinePanelLeadingOffset)
                                .padding(.top, ChromeStyle.outlinePanelTopInset)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                                .zIndex(2)
                        }
                    }
                }
            }
            .animation(ChromeStyle.outlinePanelAnimation, value: isOutlineVisible)

            Divider()

            EditorStatusBarView(
                editor: editor,
                selectedCountMetric: $selectedCountMetric
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .liteTextEditorShowSettings)) { _ in
            isSettingsPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .liteTextEditorToggleOutline)) { _ in
            withAnimation(ChromeStyle.outlinePanelAnimation) {
                isOutlineVisible.toggle()
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            LiteTextEditorSettingsView(
                isAutosaveEnabled: Binding(
                    get: { editor.isAutosaveEnabled },
                    set: { editor.setAutosaveEnabled($0) }
                ),
                suggestionWordsText: $suggestionWordsText,
                suggestionWordOptions: suggestionWordOptions,
                onSuggestionWordsCommit: applySuggestionWordsText
            )
        }
    }

    private func outlinePanelHeight(for editorHeight: CGFloat) -> CGFloat {
        max(0, editorHeight - ChromeStyle.outlinePanelTopInset - ChromeStyle.outlinePanelBottomInset)
    }

    private func applySuggestionWordsText(_ text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawValue = Double(normalizedText), rawValue.isFinite else {
            suggestionWordsText = "\(Int(suggestionWords))"
            return
        }

        let clampedValue = min(max(Int(rawValue.rounded()), 2), 5)
        suggestionWords = Double(clampedValue)
        suggestionWordsText = "\(clampedValue)"
    }
}
