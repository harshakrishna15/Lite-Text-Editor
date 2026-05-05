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
    @State private var suggestionWords: Double
    @State private var suggestionWordsText: String
    @State private var isSettingsPresented = false
    @State private var isOutlineVisible = false
    @State private var isLiveResizing = false
    @State private var editorWindowID: ObjectIdentifier?
    private let suggestionWordOptions = ["2", "3", "4", "5"]

    init(editor: EditorController = EditorController()) {
        let initialSuggestionWords = AutocompleteSettingsStore.loadMaxSuggestionWords()
        _editor = StateObject(wrappedValue: editor)
        _suggestionWords = State(initialValue: Double(initialSuggestionWords))
        _suggestionWordsText = State(initialValue: "\(initialSuggestionWords)")
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RichTextEditor(
                    controller: editor,
                    maxSuggestionWords: Int(suggestionWords),
                    isInlineSuggestionsEnabled: editor.isInlineSuggestionsEnabled,
                    isContinuousSpellCheckingEnabled: editor.isContinuousSpellCheckingEnabled,
                    isGrammarCheckingEnabled: editor.isGrammarCheckingEnabled,
                    isAutomaticTextReplacementEnabled: editor.isAutomaticTextReplacementEnabled,
                    isAutomaticQuoteSubstitutionEnabled: editor.isAutomaticQuoteSubstitutionEnabled,
                    isAutomaticDashSubstitutionEnabled: editor.isAutomaticDashSubstitutionEnabled
                )
                .clipped()
                .background(Color(nsColor: .liteTextEditorDesk))

                if editor.spellCorrectionState.isPresented {
                    SpellingCorrectionCard(
                        state: editor.spellCorrectionState,
                        onSelectSuggestion: editor.selectSpellingSuggestion,
                        onApply: editor.applyCurrentSpellingCorrection,
                        onIgnore: editor.ignoreCurrentSpellingIssue,
                        onClose: editor.closeSpellingReview
                    )
                    .padding(.top, editorOverlayTopInset + 14)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(2)
                }

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
                                .padding(.top, editorOverlayTopInset + ChromeStyle.outlinePanelTopInset)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                                .zIndex(2)
                        }
                    }
                }

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
                .zIndex(3)
            }
            .animation(ChromeStyle.outlinePanelAnimation, value: isOutlineVisible)

            Divider()

            EditorStatusBarView(editor: editor)
        }
        .background(Color(nsColor: .liteTextEditorDesk))
        .background(WindowLiveResizeReader(windowID: $editorWindowID))
        .preferredColorScheme(ChromeStyle.preferredColorScheme)
        .environment(\.isChromeGlassLiveResizing, isLiveResizing)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willStartLiveResizeNotification)) { notification in
            guard isEditorWindowNotification(notification) else { return }
            isLiveResizing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndLiveResizeNotification)) { notification in
            guard isEditorWindowNotification(notification) else { return }
            isLiveResizing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .liteTextEditorShowSettings)) { _ in
            isSettingsPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .liteTextEditorToggleOutline)) { _ in
            withAnimation(ChromeStyle.outlinePanelAnimation) {
                isOutlineVisible.toggle()
            }
        }
        .onChange(of: editor.formattingState) { formattingState in
            syncFormattingControls(with: formattingState)
        }
        .sheet(isPresented: $isSettingsPresented) {
            LiteTextEditorSettingsView(
                isContinuousSpellCheckingEnabled: Binding(
                    get: { editor.isContinuousSpellCheckingEnabled },
                    set: { editor.setContinuousSpellCheckingEnabled($0) }
                ),
                isGrammarCheckingEnabled: Binding(
                    get: { editor.isGrammarCheckingEnabled },
                    set: { editor.setGrammarCheckingEnabled($0) }
                ),
                isAutomaticTextReplacementEnabled: Binding(
                    get: { editor.isAutomaticTextReplacementEnabled },
                    set: { editor.setAutomaticTextReplacementEnabled($0) }
                ),
                isAutomaticQuoteSubstitutionEnabled: Binding(
                    get: { editor.isAutomaticQuoteSubstitutionEnabled },
                    set: { editor.setAutomaticQuoteSubstitutionEnabled($0) }
                ),
                isAutomaticDashSubstitutionEnabled: Binding(
                    get: { editor.isAutomaticDashSubstitutionEnabled },
                    set: { editor.setAutomaticDashSubstitutionEnabled($0) }
                ),
                isInlineSuggestionsEnabled: Binding(
                    get: { editor.isInlineSuggestionsEnabled },
                    set: { editor.setInlineSuggestionsEnabled($0) }
                ),
                shouldReopenLastDocument: Binding(
                    get: { editor.shouldReopenLastDocument },
                    set: { editor.setShouldReopenLastDocument($0) }
                ),
                suggestionWordsText: $suggestionWordsText,
                localModelState: editor.localModelState,
                suggestionWordOptions: suggestionWordOptions,
                onRefreshLocalModelState: editor.refreshLocalModelState,
                onDownloadLocalModel: editor.downloadLocalModel,
                onCancelLocalModelDownload: editor.cancelLocalModelDownload,
                onUninstallLocalModel: editor.uninstallLocalModel,
                onShowLocalModelDownloadLocation: editor.showLocalModelDownloadLocation,
                onSuggestionWordsCommit: applySuggestionWordsText
            )
        }
        .onAppear {
            editor.refreshLocalModelState()
        }
    }

    private func outlinePanelHeight(for editorHeight: CGFloat) -> CGFloat {
        max(0, editorHeight - editorOverlayTopInset - ChromeStyle.outlinePanelTopInset - ChromeStyle.outlinePanelBottomInset)
    }

    private var editorOverlayTopInset: CGFloat {
        ChromeStyle.regularToolbarHeight
    }

    private func isEditorWindowNotification(_ notification: Notification) -> Bool {
        guard let window = notification.object as? NSWindow else { return false }
        return ObjectIdentifier(window) == editorWindowID
    }

    private func applySuggestionWordsText(_ text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawValue = Double(normalizedText), rawValue.isFinite else {
            suggestionWordsText = "\(Int(suggestionWords))"
            return
        }

        let clampedValue = AutocompleteSettingsStore.normalizedSuggestionWordCount(Int(rawValue.rounded()))
        suggestionWords = Double(clampedValue)
        suggestionWordsText = "\(clampedValue)"
        AutocompleteSettingsStore.saveMaxSuggestionWords(clampedValue)
    }

    private func syncFormattingControls(with formattingState: FormattingState) {
        selectedFont = formattingState.fontFamilyName
        selectedSize = formattingState.fontSize
        selectedSizeText = formattedSize(formattingState.fontSize)
        textColor = Color(nsColor: formattingState.textColor)
    }

    private func formattedSize(_ size: Double) -> String {
        size.rounded() == size ? "\(Int(size))" : String(format: "%.1f", size)
    }
}

private struct WindowLiveResizeReader: NSViewRepresentable {
    @Binding var windowID: ObjectIdentifier?

    func makeNSView(context: Context) -> WindowLiveResizeView {
        let view = WindowLiveResizeView()
        updateWindowChangeHandler(for: view)
        return view
    }

    func updateNSView(_ view: WindowLiveResizeView, context: Context) {
        updateWindowChangeHandler(for: view)
        view.publishWindowIdentity()
    }

    private func updateWindowChangeHandler(for view: WindowLiveResizeView) {
        let windowID = $windowID
        view.onWindowChange = { windowID.wrappedValue = $0 }
    }
}

private final class WindowLiveResizeView: NSView {
    var onWindowChange: (ObjectIdentifier?) -> Void = { _ in }
    private var publishedWindowID: ObjectIdentifier?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publishWindowIdentity()
    }

    func publishWindowIdentity() {
        let currentWindowID = window.map(ObjectIdentifier.init)
        guard currentWindowID != publishedWindowID else { return }

        publishedWindowID = currentWindowID
        DispatchQueue.main.async { [onWindowChange] in
            onWindowChange(currentWindowID)
        }
    }
}
