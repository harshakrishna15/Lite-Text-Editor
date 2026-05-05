import AppKit
import Combine

final class EditorController: ObservableObject {
    let suggestionProvider: SuggestionProviding
    private let localModelProvider: LocalModelSuggestionProviding?
    private var localModelDownloadTask: Task<Void, Never>?

    weak var textView: AutocompleteTextView?
    weak var scrollView: NSScrollView? {
        didSet {
            (oldValue as? PaperScrollView)?.onMagnifyGesture = nil
            configureZoomForCurrentScrollView()
        }
    }

    @Published var selectedZoomPreset: DocumentZoomPreset = .percent125
    @Published var zoomDisplayText = "125%"
    @Published var zoomMagnification = 1.25
    @Published var documentStatistics = DocumentTextStatistics.empty
    @Published var outlineItems: [DocumentOutlineItem] = []
    @Published var documentStructureMetadata = DocumentStructureMetadata.empty
    @Published var activeOutlineItemID: String?
    @Published var spellCorrectionState = SpellCorrectionState.inactive
    @Published var predictionState = PredictionState.idle
    @Published var localModelState: LocalModelState
    @Published var formattingState = FormattingState()
    @Published var documentStatusText = "Ready"
    @Published var documentTitle = "Untitled"
    @Published var pendingDocumentDirectoryURL: URL?
    @Published var isContinuousSpellCheckingEnabled = WritingSettingsStore.loadIsContinuousSpellCheckingEnabled()
    @Published var isGrammarCheckingEnabled = WritingSettingsStore.loadIsGrammarCheckingEnabled()
    @Published var isAutomaticTextReplacementEnabled = TextCorrectionSettingsStore.loadIsAutomaticReplacementEnabled()
    @Published var isAutomaticQuoteSubstitutionEnabled = WritingSettingsStore.loadIsAutomaticQuoteSubstitutionEnabled()
    @Published var isAutomaticDashSubstitutionEnabled = WritingSettingsStore.loadIsAutomaticDashSubstitutionEnabled()
    @Published var isInlineSuggestionsEnabled = AutocompleteSettingsStore.loadIsInlineSuggestionsEnabled()
    @Published var shouldReopenLastDocument = StartupSettingsStore.loadShouldReopenLastDocument()
    var isDocumentEdited = false

    var currentDocumentURL: URL?
    var pendingDocumentStatisticsRefresh: DispatchWorkItem?
    var pendingOutlineRefresh: DispatchWorkItem?
    var pendingFormattingStateRefresh: DispatchWorkItem?
    var documentOperationID = UUID()
    var exportOperationID = UUID()
    var copiedFormattingAttributes: [NSAttributedString.Key: Any]?
    var hasRestoredLastSession = false
    let documentFileStore = DocumentFileStore()
    let documentFileService = DocumentFileService()
    let recentDocumentStore = RecentDocumentStore()
    let spellingReviewController = SpellingReviewController()
    let minimumZoom: CGFloat = 0.5
    let maximumZoom: CGFloat = 2.0

    func cut() {
        textView?.cut(nil)
    }

    init(
        suggestionProvider: SuggestionProviding? = nil
    ) {
        if let suggestionProvider {
            self.suggestionProvider = suggestionProvider
            self.localModelProvider = suggestionProvider as? LocalModelSuggestionProviding
            self.localModelState = .unknown(
                modelName: (suggestionProvider as? LocalModelSuggestionProviding)?.modelName ?? "Local Model"
            )
        } else {
            let localModelProvider = LocalAISuggestionProvider()
            self.localModelProvider = localModelProvider
            self.suggestionProvider = SuggestionPipeline(
                providers: [
                    localModelProvider
                ]
            )
            self.localModelState = .unknown(modelName: localModelProvider.modelName)
        }
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

    func showLocalModelDownloadLocation() {
        let directoryURL = localModelProvider?.modelDownloadDirectoryURL
            ?? LocalModelDownloadLocation.defaultDirectoryURL

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.open(directoryURL)
        } catch {
            documentStatusText = "Could not open model folder"
        }
    }

    func refreshLocalModelState() {
        guard !localModelState.isDownloading else { return }
        guard let localModelProvider else {
            localModelState = .notInstalled(modelName: localModelState.modelName)
            return
        }

        let modelName = localModelProvider.modelName
        localModelState = .checking(modelName: modelName)

        Task { [localModelProvider] in
            let nextState: LocalModelState

            do {
                try await localModelProvider.load()
                nextState = localModelProvider.isReady
                    ? .loaded(modelName: modelName)
                    : (try await localModelProvider.isDownloaded() ? .unloaded(modelName: modelName) : .notInstalled(modelName: modelName))
            } catch {
                let isDownloaded = (try? await localModelProvider.isDownloaded()) ?? false
                nextState = isDownloaded ? .unloaded(modelName: modelName) : .notInstalled(modelName: modelName)
            }

            await MainActor.run {
                [weak self] in
                self?.localModelState = nextState
            }
        }
    }

    func downloadLocalModel() {
        guard let localModelProvider else {
            localModelState = .failed(modelName: localModelState.modelName, message: "No model provider")
            return
        }

        localModelDownloadTask?.cancel()

        let modelName = localModelProvider.modelName
        let isLoadingDownloadedModel = localModelState.canUninstall
        localModelState = isLoadingDownloadedModel
            ? .checking(modelName: modelName)
            : .downloading(modelName: modelName, progress: nil)

        localModelDownloadTask = Task { [localModelProvider] in
            let nextState: LocalModelState
            let progressHandler: LocalModelDownloadProgressHandler = { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.localModelState.isDownloading else { return }
                    self.localModelState = .downloading(modelName: modelName, progress: progress)
                }
            }

            do {
                try await localModelProvider.download(progressHandler: progressHandler)
                guard !Task.isCancelled else { return }
                nextState = localModelProvider.isReady
                    ? .loaded(modelName: modelName)
                    : (try await localModelProvider.isDownloaded() ? .unloaded(modelName: modelName) : .notInstalled(modelName: modelName))
            } catch {
                guard !Task.isCancelled else { return }
                nextState = .failed(modelName: modelName, message: "Download failed")
            }

            await MainActor.run {
                [weak self] in
                self?.localModelDownloadTask = nil
                self?.localModelState = nextState
            }
        }
    }

    func cancelLocalModelDownload() {
        let modelName = localModelState.modelName
        localModelDownloadTask?.cancel()
        localModelDownloadTask = nil

        guard let localModelProvider else {
            localModelState = .notInstalled(modelName: modelName)
            return
        }

        localModelState = .uninstalling(modelName: modelName)

        Task { [localModelProvider] in
            try? await localModelProvider.uninstall()

            await MainActor.run {
                [weak self] in
                self?.localModelState = .notInstalled(modelName: modelName)
            }
        }
    }

    func uninstallLocalModel() {
        guard !localModelState.isBusy else { return }
        guard let localModelProvider else {
            localModelState = .failed(modelName: localModelState.modelName, message: "No model provider")
            return
        }

        let modelName = localModelProvider.modelName
        localModelState = .uninstalling(modelName: modelName)

        Task { [localModelProvider] in
            let nextState: LocalModelState

            do {
                try await localModelProvider.uninstall()
                nextState = .notInstalled(modelName: modelName)
            } catch {
                let isDownloaded = (try? await localModelProvider.isDownloaded()) ?? false
                nextState = isDownloaded
                    ? .unloaded(modelName: modelName)
                    : .failed(modelName: modelName, message: "Uninstall failed")
            }

            await MainActor.run {
                [weak self] in
                self?.textView?.clearSuggestion()
                self?.localModelState = nextState
            }
        }
    }
}
