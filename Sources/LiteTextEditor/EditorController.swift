import AppKit
import Combine

final class EditorController: ObservableObject {
    weak var textView: AutocompleteTextView?
    weak var scrollView: NSScrollView? {
        didSet {
            configureZoomForCurrentScrollView()
        }
    }

    @Published var selectedZoomPreset: DocumentZoomPreset = .actualSize
    @Published var zoomDisplayText = "100%"
    @Published var zoomMagnification = 1.0
    @Published var documentStatistics = DocumentTextStatistics.empty
    @Published var outlineItems: [DocumentOutlineItem] = []
    @Published var activeOutlineItemID: String?
    @Published var spellCorrectionState = SpellCorrectionState.inactive
    @Published var formattingState = FormattingState()
    @Published var documentStatusText = "Ready"
    @Published var isAutosaveEnabled = AutosaveSettingsStore.loadIsEnabled()
    var isDocumentEdited = false

    var currentDocumentURL: URL?
    let spellingDocumentTag = NSSpellChecker.uniqueSpellDocumentTag()
    var ignoredSpellingRanges: [NSRange] = []
    var pendingDocumentStatisticsRefresh: DispatchWorkItem?
    var pendingAutosaveWorkItem: DispatchWorkItem?
    var hasRestoredLastSession = false
    let minimumZoom: CGFloat = 0.5
    let maximumZoom: CGFloat = 2.0

    func cut() {
        textView?.cut(nil)
    }

    func copy() {
        textView?.copy(nil)
    }

    func paste() {
        textView?.paste(nil)
    }
}
