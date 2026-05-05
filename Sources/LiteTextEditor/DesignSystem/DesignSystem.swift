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
    static let toolbarControlCornerRadius: CGFloat = 5
    static let toolbarPopoverRowCornerRadius: CGFloat = 6
    static let toolbarPickerCornerRadius: CGFloat = 6
    static let toolbarPickerChevronWidth: CGFloat = 16
    static let toolbarPickerChevronTrailingPadding: CGFloat = 8
    static let toolbarPickerFill = Color(nsColor: .controlColor).opacity(0.90)
    static let toolbarPickerBorder = Color.black.opacity(0.18)
    static let toolbarPickerTopHighlight = Color.white.opacity(0.38)
    static let toolbarPanelHeight: CGFloat = 40
    static let toolbarFloatingTopPadding: CGFloat = 8
    static let toolbarFloatingBottomPadding: CGFloat = 6
    static let toolbarFloatingHorizontalMargin: CGFloat = 16
    static let toolbarPanelCornerRadius: CGFloat = 12
    static let regularToolbarHeight: CGFloat = toolbarPanelHeight + toolbarFloatingTopPadding + toolbarFloatingBottomPadding
    static let compactToolbarHeight: CGFloat = toolbarPanelHeight + toolbarFloatingTopPadding + toolbarFloatingBottomPadding
    static let toolbarCompactBreakpoint: CGFloat = 1_545
    static let toolbarRegularBreakpoint: CGFloat = 1_595
    static let toolbarModeInitialBreakpoint: CGFloat = 1_570
    static let toolbarHorizontalPadding: CGFloat = 18
    static let compactToolbarHorizontalPadding: CGFloat = 12
    static let toolbarModeAnimation = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 145,
        damping: 24,
        initialVelocity: 0
    )
    static let toolbarFontControlWidth: CGFloat = 260
    static let compactToolbarFontControlWidth: CGFloat = 200
    static let toolbarSizeControlWidth: CGFloat = 78
    static let toolbarStyleControlWidth: CGFloat = 170
    static let compactToolbarStyleControlWidth: CGFloat = 132
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
    static let chromeBarBackground = Color(nsColor: .controlBackgroundColor)
    static let chromePanelBackground = Color(nsColor: .windowBackgroundColor).opacity(0.98)
    static let chromeControlBackground = Color(nsColor: .controlColor).opacity(0.72)
    static let chromeControlBorder = Color(nsColor: .separatorColor).opacity(0.64)
    static let chromePanelBorder = Color(nsColor: .separatorColor).opacity(0.56)
    static let chromeBarBorder = Color(nsColor: .separatorColor).opacity(0.50)
    static let chromeSelectedControlBackground = Color.accentColor.opacity(0.14)
    static let chromePressedControlBackground = Color.accentColor.opacity(0.18)
    static let toolbarHoverFill = Color(nsColor: .controlColor).opacity(0.72)
    static let toolbarPressedFill = chromePressedControlBackground
    static let toolbarSelectedFill = chromeSelectedControlBackground
    static let toolbarSelectedBorder = Color.accentColor.opacity(0.62)
    static let toolbarHoverBorder = Color.accentColor.opacity(0.40)
    static let toolbarHoverOverlay = Color.accentColor.opacity(0.055)

    static var appearance: NSAppearance? {
        NSAppearance(named: appearanceName)
    }
}
