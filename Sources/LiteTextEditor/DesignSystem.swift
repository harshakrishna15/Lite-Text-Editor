import AppKit
import SwiftUI

enum ChromeStyle {
    static let controlFontSize = NSFont.systemFontSize(for: .regular)
    static let smallFontSize = NSFont.systemFontSize(for: .small)
    static let controlTextFont = Font.system(size: controlFontSize, weight: .regular)
    static let smallTextFont = Font.system(size: smallFontSize, weight: .regular)
    static let controlSymbolFont = Font.system(size: controlFontSize, weight: .medium)
    static let largeSymbolFont = Font.system(size: 17, weight: .regular)
    static let toolbarControlHeight: CGFloat = 26
    static let regularToolbarHeight: CGFloat = 40
    static let compactToolbarHeight: CGFloat = 40
    static let toolbarCompactBreakpoint: CGFloat = 1_205
    static let toolbarRegularBreakpoint: CGFloat = 1_255
    static let toolbarModeInitialBreakpoint: CGFloat = 1_230
    static let toolbarModeAnimation = Animation.easeInOut(duration: 0.32)
    static let toolbarIconWidth: CGFloat = 28
    static let toolbarItemSpacing: CGFloat = 7
    static let toolbarSectionSpacing: CGFloat = 10
    static let outlinePanelWidth: CGFloat = 250
    static let outlinePanelLeadingOffset: CGFloat = 16
    static let outlinePanelTopInset: CGFloat = 16
    static let outlinePanelBottomInset: CGFloat = 16
    static let outlinePanelAnimation = Animation.easeInOut(duration: 0.22)
    static let controlTextColor = Color(nsColor: .controlTextColor)
    static let secondaryTextColor = Color(nsColor: .secondaryLabelColor)
    static let toolbarHoverFill = Color(nsColor: .controlColor).opacity(0.72)
    static let toolbarPressedFill = Color(nsColor: .selectedControlColor).opacity(0.28)
    static let toolbarSelectedFill = Color.accentColor.opacity(0.18)
}
