import Foundation

enum AutosaveStatus: Equatable {
    case off
    case unavailable
    case clean
    case pending
    case saving
    case saved
    case failed

    var title: String {
        switch self {
        case .off:
            return "Autosave Off"
        case .unavailable:
            return "Save to enable autosave"
        case .clean:
            return "Autosave Ready"
        case .pending:
            return "Autosave Pending"
        case .saving:
            return "Autosaving"
        case .saved:
            return "Autosaved"
        case .failed:
            return "Autosave Failed"
        }
    }
}
