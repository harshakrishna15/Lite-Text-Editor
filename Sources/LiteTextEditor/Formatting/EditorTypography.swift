import AppKit

enum EditorTypography {
    static let displayName = "Courier"
    static let defaultPointSize: CGFloat = 12

    static var defaultTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font(size: defaultPointSize),
            .foregroundColor: NSColor.black
        ]
    }

    static func font(
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        italic: Bool = false
    ) -> NSFont {
        let isBold = weight.rawValue >= NSFont.Weight.semibold.rawValue
        let names: [String]

        switch (isBold, italic) {
        case (true, true):
            names = ["CourierNewPS-BoldItalicMT", "Courier-BoldOblique"]
        case (true, false):
            names = ["CourierNewPS-BoldMT", "Courier-Bold"]
        case (false, true):
            names = ["CourierNewPS-ItalicMT", "Courier-Oblique"]
        case (false, false):
            names = ["CourierNewPSMT", "Courier"]
        }

        for name in names {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }

        let fallback = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        guard italic else { return fallback }

        let traits = fallback.fontDescriptor.symbolicTraits.union(.italic)
        let descriptor = fallback.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: size) ?? fallback
    }

    static func font(matching source: NSFont) -> NSFont {
        let traits = source.fontDescriptor.symbolicTraits
        return font(
            size: source.pointSize,
            weight: traits.contains(.bold) ? .bold : .regular,
            italic: traits.contains(.italic)
        )
    }

    static func isAllowedFont(_ font: NSFont) -> Bool {
        let identity = [font.familyName, font.fontName]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if identity.contains("courier") {
            return true
        }

        let courierIsAvailable = NSFont(name: "CourierNewPSMT", size: defaultPointSize) != nil
            || NSFont(name: "Courier", size: defaultPointSize) != nil
        return !courierIsAvailable && font.fontDescriptor.symbolicTraits.contains(.monoSpace)
    }

    static func normalizedAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let normalized = NSMutableAttributedString(attributedString: attributedString)
        enforceFont(in: normalized)
        return normalized.copy() as? NSAttributedString ?? NSAttributedString(attributedString: normalized)
    }

    static func enforceFont(in attributedString: NSMutableAttributedString) {
        guard attributedString.length > 0 else { return }

        let fullRange = NSRange(location: 0, length: attributedString.length)
        var replacements: [(range: NSRange, font: NSFont)] = []

        attributedString.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if let sourceFont = value as? NSFont {
                guard !isAllowedFont(sourceFont) else { return }
                replacements.append((range, font(matching: sourceFont)))
            } else {
                replacements.append((range, font(size: defaultPointSize)))
            }
        }

        guard !replacements.isEmpty else { return }
        attributedString.beginEditing()
        replacements.forEach { replacement in
            attributedString.addAttribute(.font, value: replacement.font, range: replacement.range)
        }
        attributedString.endEditing()
    }

    static func normalizedTypingAttributes(
        _ attributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var normalized = attributes
        let sourceFont = attributes[.font] as? NSFont ?? font(size: defaultPointSize)
        normalized[.font] = isAllowedFont(sourceFont) ? sourceFont : font(matching: sourceFont)
        normalized[.foregroundColor] = attributes[.foregroundColor] ?? NSColor.black
        return normalized
    }
}
