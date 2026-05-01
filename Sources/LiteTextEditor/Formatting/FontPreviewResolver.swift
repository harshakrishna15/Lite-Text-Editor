import AppKit

struct FontPreviewResolver {
    static let previewSize: CGFloat = NSFont.systemFontSize(for: .regular)

    func font(for displayName: String, size: CGFloat = Self.previewSize) -> NSFont {
        guard displayName != "System" else {
            return NSFont.systemFont(ofSize: size)
        }

        if let familyFont = NSFontManager.shared.font(
            withFamily: displayName,
            traits: [],
            weight: 5,
            size: size
        ) {
            return familyFont
        }

        if let namedFont = NSFont(name: displayName, size: size) {
            return namedFont
        }

        return NSFont.systemFont(ofSize: size)
    }

    func attributedTitle(for displayName: String, size: CGFloat = Self.previewSize) -> NSAttributedString {
        NSAttributedString(
            string: displayName,
            attributes: [
                .font: font(for: displayName, size: size),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }
}
