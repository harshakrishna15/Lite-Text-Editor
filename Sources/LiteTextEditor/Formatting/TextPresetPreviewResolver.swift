import AppKit

struct TextPresetPreviewResolver {
    private let fontPreviewResolver = FontPreviewResolver()

    func menuTitle(for preset: TextPreset, fontName: String) -> NSAttributedString {
        NSAttributedString(
            string: preset.title,
            attributes: attributes(
                for: preset,
                fontName: fontName,
                size: menuPreviewSize(for: preset)
            )
        )
    }

    func buttonTitle(for preset: TextPreset, fontName: String) -> NSAttributedString {
        NSAttributedString(
            string: preset.title,
            attributes: attributes(
                for: preset,
                fontName: fontName,
                size: buttonPreviewSize(for: preset)
            )
        )
    }

    func menuPreviewSize(for preset: TextPreset) -> CGFloat {
        switch preset {
        case .title:
            return 22
        case .heading:
            return 19
        case .subheading:
            return 17
        case .script:
            return 15
        case .body:
            return 13
        }
    }

    func buttonPreviewSize(for preset: TextPreset) -> CGFloat {
        switch preset {
        case .title:
            return 16
        case .heading:
            return 15
        case .subheading, .script:
            return 14
        case .body:
            return 13
        }
    }

    private func attributes(
        for preset: TextPreset,
        fontName: String,
        size: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: previewFont(for: preset, fontName: fontName, size: size),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private func previewFont(for preset: TextPreset, fontName: String, size: CGFloat) -> NSFont {
        let baseFont = fontPreviewResolver.font(for: fontName, size: size)
        let descriptor = baseFont.fontDescriptor.addingAttributes([
            .traits: [
                NSFontDescriptor.TraitKey.weight: preset.weight.rawValue
            ]
        ])

        return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: preset.weight)
    }
}
