import AppKit

enum TextPreset: String, CaseIterable, Identifiable {
    case title
    case heading
    case subheading
    case body
    case script

    var id: String { rawValue }

    var title: String {
        switch self {
        case .title:
            return "Title"
        case .heading:
            return "Heading"
        case .subheading:
            return "Subheading"
        case .body:
            return "Body"
        case .script:
            return "Script"
        }
    }

    var size: Double {
        switch self {
        case .title:
            return 32
        case .heading:
            return 24
        case .subheading:
            return 20
        case .body:
            return 11
        case .script:
            return 16
        }
    }

    var weight: NSFont.Weight {
        switch self {
        case .title:
            return .bold
        case .heading:
            return .semibold
        case .subheading:
            return .medium
        case .body, .script:
            return .regular
        }
    }

    var paragraphSpacingBefore: CGFloat {
        switch self {
        case .title:
            return 0
        case .heading:
            return 14
        case .subheading:
            return 10
        case .body:
            return 0
        case .script:
            return 6
        }
    }

    var paragraphSpacingAfter: CGFloat {
        switch self {
        case .title:
            return 12
        case .heading:
            return 8
        case .subheading:
            return 6
        case .body:
            return 0
        case .script:
            return 4
        }
    }

    var lineHeightMultiple: CGFloat {
        switch self {
        case .title:
            return 1.0
        case .heading, .subheading:
            return 1.08
        case .body:
            return 1.0
        case .script:
            return 1.2
        }
    }
}
