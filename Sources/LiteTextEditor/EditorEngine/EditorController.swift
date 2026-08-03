import AppKit
import Combine

final class EditorController: ObservableObject {
    let suggestionProvider: SuggestionProviding

    weak var textView: AutocompleteTextView?
    weak var scrollView: NSScrollView?

    @Published var documentStatistics = DocumentTextStatistics.empty
    @Published var outlineItems: [DocumentOutlineItem] = []
    @Published var documentStructureMetadata = DocumentStructureMetadata.empty
    @Published var activeOutlineItemID: String?
    @Published var spellCorrectionState = SpellCorrectionState.inactive
    @Published var predictionState = PredictionState.idle
    @Published var formattingState = FormattingState()
    @Published var documentTitle = "Untitled"
    @Published var pendingDocumentDirectoryURL: URL?
    @Published var documentTabs: [DocumentTabDescriptor] = []
    @Published var selectedDocumentTabID: UUID?
    @Published var isOutlineVisible = false
    @Published var isContinuousSpellCheckingEnabled = WritingSettingsStore.loadIsContinuousSpellCheckingEnabled()
    @Published var isGrammarCheckingEnabled = WritingSettingsStore.loadIsGrammarCheckingEnabled()
    @Published var isAutomaticTextReplacementEnabled = WritingSettingsStore.loadIsAutomaticReplacementEnabled()
    @Published var isAutomaticQuoteSubstitutionEnabled = WritingSettingsStore.loadIsAutomaticQuoteSubstitutionEnabled()
    @Published var isAutomaticDashSubstitutionEnabled = WritingSettingsStore.loadIsAutomaticDashSubstitutionEnabled()
    @Published var isInlineSuggestionsEnabled = AutocompleteSettingsStore.loadIsInlineSuggestionsEnabled()
    @Published var shouldReopenLastDocument = StartupSettingsStore.loadShouldReopenLastDocument()
    var isDocumentEdited = false

    var currentDocumentURL: URL?
    var documentTabContents: [UUID: NSAttributedString] = [:]
    var documentTabSelections: [UUID: NSRange] = [:]
    var documentTabVisibleOrigins: [UUID: NSPoint] = [:]
    var documentTabUndoManagers: [UUID: UndoManager] = [:]
    var nextAutomaticDocumentTabNumber = 1
    var documentGeneration = 0
    var isEnforcingEditorTypography = false
    var pendingDocumentStatisticsRefresh: DispatchWorkItem?
    var pendingOutlineRefresh: DispatchWorkItem?
    var pendingFormattingStateRefresh: DispatchWorkItem?
    var documentReadOperationID = UUID()
    var documentWriteOperationID = UUID()
    var exportOperationID = UUID()
    var isDocumentWriteInProgress = false
    var copiedFormattingAttributes: [NSAttributedString.Key: Any]?
    var hasRestoredLastSession = false
    let documentFileStore = DocumentFileStore()
    let documentFileService = DocumentFileService()
    let recentDocumentStore = RecentDocumentStore()
    let spellingReviewController = SpellingReviewController()

    func cut() {
        textView?.cut(nil)
    }

    init(
        suggestionProvider: SuggestionProviding? = nil
    ) {
        self.suggestionProvider = suggestionProvider ?? PhraseSuggestionEngine()

        installDocument(EditorDocument.blank(), loadsSelectedTab: false)
    }

    func copy() {
        textView?.copy(nil)
    }

    func paste() {
        textView?.paste(nil)
    }

    func updatePredictionState(_ state: PredictionState) {
        guard predictionState != state else { return }
        predictionState = state
    }
}
