import AppKit

enum SystemFontName {
    static let displayName = "System"

    static func isSystemDisplayName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName == displayName || isPrivateSystemFontName(trimmedName)
    }

    static func displayName(for font: NSFont) -> String {
        if isSystemFont(font) {
            return displayName
        }

        return font.familyName ?? font.displayName ?? font.fontName
    }

    static func isSystemFont(_ font: NSFont) -> Bool {
        let systemFontFamily = NSFont.systemFont(ofSize: font.pointSize).familyName
        let candidateNames = [
            font.fontName,
            font.familyName,
            font.displayName,
            font.fontDescriptor.object(forKey: .name) as? String,
            font.fontDescriptor.object(forKey: .family) as? String
        ]

        return candidateNames.contains { name in
            guard let name else { return false }
            return name == systemFontFamily || isPrivateSystemFontName(name)
        }
    }

    private static func isPrivateSystemFontName(_ name: String) -> Bool {
        name.hasPrefix(".AppleSystem") || name.hasPrefix(".SF")
    }
}
