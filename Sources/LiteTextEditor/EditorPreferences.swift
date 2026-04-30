import AppKit
import SwiftUI

enum AutosaveStore {
    private static let lastDocumentURLKey = "LiteTextEditor.lastDocumentURL"

    static var lastDocumentURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: lastDocumentURLKey),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    static func saveLastDocumentURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastDocumentURLKey)
    }
}

enum AutosaveSettingsStore {
    private static let isEnabledKey = "LiteTextEditor.autosaveEnabled"

    static func loadIsEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: isEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: isEnabledKey)
    }

    static func saveIsEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: isEnabledKey)
    }
}

struct PaletteColor: Codable, Equatable, Identifiable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var id: String {
        "\(red)-\(green)-\(blue)-\(alpha)"
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    private var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.normalized(red)
        self.green = Self.normalized(green)
        self.blue = Self.normalized(blue)
        self.alpha = Self.normalized(alpha)
    }

    init(_ color: Color) {
        let nsColor = NSColor(color)
            .usingColorSpace(.deviceRGB)
            ?? NSColor.black

        self.init(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
    }

    private static func normalized(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 1)
        return (clampedValue * 1_000).rounded() / 1_000
    }
}

struct TextColorPreset: Identifiable {
    let name: String
    let color: PaletteColor

    var id: String { name }

    static let all: [TextColorPreset] = [
        TextColorPreset(name: "Black", color: PaletteColor(red: 0.00, green: 0.00, blue: 0.00)),
        TextColorPreset(name: "Dark Gray", color: PaletteColor(red: 0.23, green: 0.23, blue: 0.23)),
        TextColorPreset(name: "Gray", color: PaletteColor(red: 0.55, green: 0.55, blue: 0.55)),
        TextColorPreset(name: "Red", color: PaletteColor(red: 0.82, green: 0.10, blue: 0.14)),
        TextColorPreset(name: "Orange", color: PaletteColor(red: 0.93, green: 0.43, blue: 0.12)),
        TextColorPreset(name: "Yellow", color: PaletteColor(red: 0.95, green: 0.78, blue: 0.17)),
        TextColorPreset(name: "Green", color: PaletteColor(red: 0.17, green: 0.57, blue: 0.25)),
        TextColorPreset(name: "Teal", color: PaletteColor(red: 0.09, green: 0.50, blue: 0.54)),
        TextColorPreset(name: "Blue", color: PaletteColor(red: 0.10, green: 0.35, blue: 0.80)),
        TextColorPreset(name: "Purple", color: PaletteColor(red: 0.43, green: 0.24, blue: 0.74)),
        TextColorPreset(name: "Pink", color: PaletteColor(red: 0.80, green: 0.20, blue: 0.49)),
        TextColorPreset(name: "Brown", color: PaletteColor(red: 0.49, green: 0.30, blue: 0.18))
    ]
}

enum TextColorPaletteStore {
    static let maximumCustomColors = 18

    private static let key = "LiteTextEditor.customTextColors"

    static func load() -> [PaletteColor] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let colors = try? JSONDecoder().decode([PaletteColor].self, from: data) else {
            return []
        }

        return Array(colors.suffix(maximumCustomColors))
    }

    static func save(_ colors: [PaletteColor]) {
        guard let data = try? JSONEncoder().encode(Array(colors.suffix(maximumCustomColors))) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }
}
