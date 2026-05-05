import AppKit

protocol MenuTitledOption {
    var title: String { get }
}

enum TextBaselineOption: String, CaseIterable, MenuTitledOption {
    case normal
    case superscript
    case `subscript`

    var title: String {
        switch self {
        case .normal:
            return "Normal Baseline"
        case .superscript:
            return "Superscript"
        case .subscript:
            return "Subscript"
        }
    }

    var offset: Int {
        switch self {
        case .normal:
            return 0
        case .superscript:
            return 1
        case .subscript:
            return -1
        }
    }
}

enum TextCasingOption: String, CaseIterable, MenuTitledOption {
    case uppercase
    case lowercase
    case capitalizeWords
    case smallCaps

    var title: String {
        switch self {
        case .uppercase:
            return "All Caps"
        case .lowercase:
            return "Lowercase"
        case .capitalizeWords:
            return "Capitalize Words"
        case .smallCaps:
            return "Small Caps"
        }
    }
}

enum CharacterSpacingOption: String, CaseIterable, MenuTitledOption {
    case tighter
    case normal
    case wider

    var title: String {
        switch self {
        case .tighter:
            return "Tighter"
        case .normal:
            return "Normal"
        case .wider:
            return "Wider"
        }
    }

    var kern: CGFloat? {
        switch self {
        case .tighter:
            return -0.5
        case .normal:
            return nil
        case .wider:
            return 1.0
        }
    }
}

enum HighlightColorOption: String, CaseIterable, MenuTitledOption {
    case yellow
    case green
    case blue
    case pink
    case orange
    case clear

    var title: String {
        switch self {
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .pink:
            return "Pink"
        case .orange:
            return "Orange"
        case .clear:
            return "Clear Highlight"
        }
    }

    var color: NSColor? {
        switch self {
        case .yellow:
            return NSColor.systemYellow.withAlphaComponent(0.45)
        case .green:
            return NSColor.systemGreen.withAlphaComponent(0.32)
        case .blue:
            return NSColor.systemBlue.withAlphaComponent(0.25)
        case .pink:
            return NSColor.systemPink.withAlphaComponent(0.28)
        case .orange:
            return NSColor.systemOrange.withAlphaComponent(0.32)
        case .clear:
            return nil
        }
    }
}

enum LineSpacingOption: String, CaseIterable, MenuTitledOption {
    case single
    case relaxed
    case oneAndHalf
    case double

    var title: String {
        switch self {
        case .single:
            return "1.0"
        case .relaxed:
            return "1.15"
        case .oneAndHalf:
            return "1.5"
        case .double:
            return "2.0"
        }
    }

    var multiple: CGFloat {
        switch self {
        case .single:
            return 1.0
        case .relaxed:
            return 1.15
        case .oneAndHalf:
            return 1.5
        case .double:
            return 2.0
        }
    }
}

enum ParagraphSpacingOption: String, CaseIterable, MenuTitledOption {
    case before
    case after
    case remove

    var title: String {
        switch self {
        case .before:
            return "Add Space Before"
        case .after:
            return "Add Space After"
        case .remove:
            return "Remove Paragraph Spacing"
        }
    }
}

enum ParagraphIndentOption: String, CaseIterable, MenuTitledOption {
    case firstLine
    case hanging
    case clear

    var title: String {
        switch self {
        case .firstLine:
            return "First-Line Indent"
        case .hanging:
            return "Hanging Indent"
        case .clear:
            return "Clear Paragraph Indents"
        }
    }
}

enum ListStyleOption: String, CaseIterable, MenuTitledOption {
    case bullet
    case dash
    case numbered
    case lettered
    case roman
    case checklist

    var title: String {
        switch self {
        case .bullet:
            return "Bullet"
        case .dash:
            return "Dash"
        case .numbered:
            return "Numbered"
        case .lettered:
            return "Lettered"
        case .roman:
            return "Roman"
        case .checklist:
            return "Checklist"
        }
    }
}

enum ListNumberingAction: String, CaseIterable, MenuTitledOption {
    case restart
    case `continue`

    var title: String {
        switch self {
        case .restart:
            return "Restart Numbering"
        case .continue:
            return "Continue Numbering"
        }
    }
}
