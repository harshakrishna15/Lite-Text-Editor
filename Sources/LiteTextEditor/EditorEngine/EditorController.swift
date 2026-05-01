import AppKit
import Combine

final class EditorController: ObservableObject {
    let suggestionProvider: SuggestionProviding

    weak var textView: AutocompleteTextView?
    weak var scrollView: NSScrollView? {
        didSet {
            (oldValue as? PaperScrollView)?.onMagnifyGesture = nil
            configureZoomForCurrentScrollView()
        }
    }

    @Published var selectedZoomPreset: DocumentZoomPreset = .actualSize
    @Published var zoomDisplayText = "100%"
    @Published var zoomMagnification = 1.0
    @Published var documentStatistics = DocumentTextStatistics.empty
    @Published var outlineItems: [DocumentOutlineItem] = []
    @Published var documentStructureMetadata = DocumentStructureMetadata.empty
    @Published var activeOutlineItemID: String?
    @Published var spellCorrectionState = SpellCorrectionState.inactive
    @Published var formattingState = FormattingState()
    @Published var documentStatusText = "Ready"
    @Published var documentTitle = "Untitled"
    @Published var pendingDocumentDirectoryURL: URL?
    @Published var isAutosaveEnabled = AutosaveSettingsStore.loadIsEnabled()
    @Published var isAutomaticTextReplacementEnabled = TextCorrectionSettingsStore.loadIsAutomaticReplacementEnabled()
    @Published var autosaveStatus: AutosaveStatus = AutosaveSettingsStore.loadIsEnabled() ? .unavailable : .off
    var isDocumentEdited = false

    var currentDocumentURL: URL?
    var pendingDocumentStatisticsRefresh: DispatchWorkItem?
    var pendingFormattingStateRefresh: DispatchWorkItem?
    var pendingAutosaveWorkItem: DispatchWorkItem?
    var hasRestoredLastSession = false
    let documentFileStore = DocumentFileStore()
    let recentDocumentStore = RecentDocumentStore()
    let autosavePolicy = AutosavePolicy()
    let spellingReviewController = SpellingReviewController()
    let minimumZoom: CGFloat = 0.5
    let maximumZoom: CGFloat = 2.0

    func cut() {
        textView?.cut(nil)
    }

    init(
        suggestionProvider: SuggestionProviding = SuggestionPipeline(
            providers: [
                PhraseSuggestionEngine(),
                LocalAISuggestionProvider()
            ]
        )
    ) {
        self.suggestionProvider = suggestionProvider
    }

    func copy() {
        textView?.copy(nil)
    }

    func paste() {
        textView?.paste(nil)
    }
}
