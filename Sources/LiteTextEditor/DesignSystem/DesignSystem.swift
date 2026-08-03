import AppKit
import SwiftUI

enum ChromeStyle {
    static let windowTitle = "Lite Text Editor"
    static let appearanceName: NSAppearance.Name = .aqua
    static let preferredColorScheme = ColorScheme.light
    static let controlFontSize = NSFont.systemFontSize(for: .regular)
    static let smallFontSize = NSFont.systemFontSize(for: .small)
    static let controlTextFont = Font.system(size: controlFontSize, weight: .regular)
    static let smallTextFont = Font.system(size: smallFontSize, weight: .regular)
    static let controlSymbolFont = Font.system(size: controlFontSize, weight: .medium)
    static let toolbarControlHeight: CGFloat = 26
    static let toolbarDropdownControlHeight: CGFloat = 20
    static let toolbarControlCornerRadius: CGFloat = 5
    static let outlinePanelWidth: CGFloat = 250
    static let outlinePanelLeadingOffset: CGFloat = 16
    static let outlinePanelTopInset: CGFloat = 16
    static let outlinePanelBottomInset: CGFloat = 16
    static let outlineCollapsedButtonWidth: CGFloat = 196
    static let outlineCollapsedIconButtonWidth: CGFloat = 32
    static let outlineCollapsedButtonHeight: CGFloat = 32
    static let outlineCollapsedButtonCornerRadius: CGFloat = 10
    static let outlinePanelAnimation = Animation.easeInOut(duration: 0.22)
    static let controlTextColor = Color.black.opacity(0.86)
    static let secondaryTextColor = Color.black.opacity(0.58)
    static let glassControlTextColor = Color.black.opacity(0.82)
    static let chromeBarBackground = Color(nsColor: .controlBackgroundColor)
    static let chromePanelBackground = Color(nsColor: .windowBackgroundColor).opacity(0.98)
    static let chromeControlBackground = Color(nsColor: .controlColor).opacity(0.72)
    static let chromeControlBorder = Color(nsColor: .separatorColor).opacity(0.64)
    static let chromePanelBorder = Color(nsColor: .separatorColor).opacity(0.56)
    static let chromeBarBorder = Color(nsColor: .separatorColor).opacity(0.50)
    static let chromeSelectedControlBackground = Color.accentColor.opacity(0.14)
    static let chromePressedControlBackground = Color.accentColor.opacity(0.18)
    static let toolbarHoverFill = Color(nsColor: .controlColor).opacity(0.72)
    static let toolbarSelectedFill = chromeSelectedControlBackground
    static let toolbarSelectedBorder = Color.accentColor.opacity(0.62)
    static let toolbarHoverBorder = Color.accentColor.opacity(0.40)
    static let toolbarHoverOverlay = Color.accentColor.opacity(0.055)

    static var appearance: NSAppearance? {
        NSAppearance(named: appearanceName)
    }
}
