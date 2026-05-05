import Foundation

enum LocalModelState: Equatable {
    case unknown(modelName: String)
    case checking(modelName: String)
    case downloading(modelName: String, progress: LocalModelDownloadProgress?)
    case uninstalling(modelName: String)
    case loaded(modelName: String)
    case unloaded(modelName: String)
    case notInstalled(modelName: String)
    case failed(modelName: String, message: String)

    var modelName: String {
        switch self {
        case .unknown(let modelName),
             .checking(let modelName),
             .downloading(let modelName, _),
             .uninstalling(let modelName),
             .loaded(let modelName),
             .unloaded(let modelName),
             .notInstalled(let modelName),
             .failed(let modelName, _):
            return modelName
        }
    }

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .uninstalling:
            return true
        case .unknown, .loaded, .unloaded, .notInstalled, .failed:
            return false
        }
    }

    var canUninstall: Bool {
        switch self {
        case .loaded, .unloaded:
            return true
        case .unknown, .checking, .downloading, .uninstalling, .notInstalled, .failed:
            return false
        }
    }

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }

        return false
    }

    var downloadProgress: LocalModelDownloadProgress? {
        if case .downloading(_, let progress) = self {
            return progress
        }

        return nil
    }

    var statusText: String {
        switch self {
        case .unknown:
            return "Not checked"
        case .checking:
            return "Checking..."
        case .downloading(_, let progress):
            return progress?.statusText ?? "Starting download..."
        case .uninstalling:
            return "Uninstalling..."
        case .loaded:
            return "Loaded"
        case .unloaded:
            return "Downloaded, not loaded"
        case .notInstalled:
            return "Not downloaded"
        case .failed(_, let message):
            return message
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .unknown, .notInstalled, .failed:
            return "Download Model"
        case .unloaded:
            return "Load Model"
        case .loaded:
            return "Refresh"
        case .checking:
            return "Checking..."
        case .downloading:
            return "Cancel Install"
        case .uninstalling:
            return "Uninstalling..."
        }
    }
}
