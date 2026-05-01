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
    static let largeSymbolFont = Font.system(size: 17, weight: .regular)
    static let toolbarControlHeight: CGFloat = 26
    static let regularToolbarHeight: CGFloat = 40
    static let compactToolbarHeight: CGFloat = 40
    static let toolbarCompactBreakpoint: CGFloat = 1_405
    static let toolbarRegularBreakpoint: CGFloat = 1_455
    static let toolbarModeInitialBreakpoint: CGFloat = 1_430
    static let toolbarModeAnimation = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 145,
        damping: 24,
        initialVelocity: 0
    )
    static let toolbarFontControlWidth: CGFloat = 260
    static let compactToolbarFontControlWidth: CGFloat = 220
    static let toolbarSizeControlWidth: CGFloat = 70
    static let toolbarStyleControlWidth: CGFloat = 170
    static let compactToolbarStyleControlWidth: CGFloat = 150
    static let toolbarIconWidth: CGFloat = 28
    static let toolbarItemSpacing: CGFloat = 7
    static let toolbarSectionSpacing: CGFloat = 10
    static let outlinePanelWidth: CGFloat = 250
    static let outlinePanelLeadingOffset: CGFloat = 16
    static let outlinePanelTopInset: CGFloat = 16
    static let outlinePanelBottomInset: CGFloat = 16
    static let outlinePanelAnimation = Animation.easeInOut(duration: 0.22)
    static let controlTextColor = Color.black.opacity(0.86)
    static let secondaryTextColor = Color.black.opacity(0.58)
    static let glassControlTextColor = Color.black.opacity(0.82)
    static let glassSecondaryTextColor = Color.black.opacity(0.58)
    static let nsGlassControlTextColor = NSColor(calibratedWhite: 0.12, alpha: 0.92)
    static let toolbarHoverFill = Color.white.opacity(0.10)
    static let toolbarPressedFill = Color.accentColor.opacity(0.22)
    static let toolbarSelectedFill = Color.accentColor.opacity(0.18)
    static let toolbarSelectedBorder = Color.accentColor.opacity(0.62)
    static let toolbarHoverBorder = Color.white.opacity(0.22)
    static let outlinePanelStroke = Color.white.opacity(0.20)

    static var appearance: NSAppearance? {
        NSAppearance(named: appearanceName)
    }
}
