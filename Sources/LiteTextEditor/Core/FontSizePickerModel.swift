import Foundation

enum FontSizePickerModel {
    static let minimumSize = 1.0
    static let maximumSize = 400.0
    static let commonSizes: [Double] = [
        8, 9, 10, 11, 12, 14, 18, 24, 30, 36, 48, 60, 72, 96
    ]

    static var commonSizeTitles: [String] {
        commonSizes.map(displayText)
    }

    static func size(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "pt", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value.isFinite else { return nil }
        return min(max(value, minimumSize), maximumSize)
    }

    static func steppedSize(from size: Double, direction: Int) -> Double {
        min(max(size + Double(direction), minimumSize), maximumSize)
    }

    static func displayText(for size: Double) -> String {
        let clampedSize = min(max(size, minimumSize), maximumSize)
        let roundedSize = (clampedSize * 100).rounded() / 100

        if roundedSize.rounded() == roundedSize {
            return String(Int(roundedSize))
        }

        return String(roundedSize)
    }
}
