import AppKit
import SwiftUI

struct EditorFormattingToolbarView: View {
    @ObservedObject var editor: EditorController
    @Binding var selectedFont: String
    @Binding var selectedSize: Double
    @Binding var selectedSizeText: String
    @Binding var selectedStyle: TextPreset
    @Binding var textColor: Color
    @Binding var customTextColors: [PaletteColor]
    @Binding var isOutlineVisible: Bool

    @State private var isCompactToolbar = false
    @Namespace private var toolbarNamespace

    private let fonts = InstalledFontProvider.fontFamilies
    private let sizes = [11.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0]

    private var sizeOptions: [String] {
        sizes.map { "\(Int($0))" }
    }

    var body: some View {
        GeometryReader { proxy in
            ChromeGlassContainer(spacing: ChromeStyle.toolbarSectionSpacing) {
                formattingBar
                    .clipped()
                    .frame(height: ChromeStyle.toolbarPanelHeight)
                    .chromeGlassBackground(
                        .toolbar,
                        in: RoundedRectangle(cornerRadius: ChromeStyle.toolbarPanelCornerRadius, style: .continuous)
                    )
                    .chromeFloatingPanelShadow()
                    .frame(
                        maxWidth: max(0, proxy.size.width - (ChromeStyle.toolbarFloatingHorizontalMargin * 2)),
                        maxHeight: .infinity,
                        alignment: .top
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, ChromeStyle.toolbarFloatingTopPadding)
            }
            .onAppear {
                updateToolbarMode(for: proxy.size.width, animated: false)
            }
            .onChange(of: proxy.size.width) { width in
                updateToolbarMode(for: width, animated: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: isCompactToolbar ? ChromeStyle.compactToolbarHeight : ChromeStyle.regularToolbarHeight)
    }

    private func updateToolbarMode(for width: CGFloat, animated: Bool) {
        let shouldUseCompactToolbar = ToolbarLayoutPolicy.shouldUseCompactToolbar(
            width: width,
            isCurrentlyCompact: isCompactToolbar,
            animated: animated
        )

        guard shouldUseCompactToolbar != isCompactToolbar else { return }

        if animated {
            withAnimation(ChromeStyle.toolbarModeAnimation) {
                isCompactToolbar = shouldUseCompactToolbar
            }
        } else {
            isCompactToolbar = shouldUseCompactToolbar
        }
    }

    private var formattingBar: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            outlineToggleButton
                .matchedGeometryEffect(id: ToolbarAnimationID.outlineToggle, in: toolbarNamespace)
            ToolbarDivider()
            stylePresetSection
                .matchedGeometryEffect(id: ToolbarAnimationID.stylePreset, in: toolbarNamespace)
            ToolbarDivider()
            fontControlsSection
                .matchedGeometryEffect(id: ToolbarAnimationID.fontControls, in: toolbarNamespace)
            ToolbarDivider()
            primaryInlineFormattingSection
                .matchedGeometryEffect(id: ToolbarAnimationID.primaryFormatting, in: toolbarNamespace)
        }
        .padding(.horizontal, toolbarHorizontalPadding)
        .padding(.vertical, 7)
        .fixedSize(horizontal: true, vertical: false)
        .animation(ChromeStyle.toolbarModeAnimation, value: isCompactToolbar)
    }

    private var outlineToggleButton: some View {
        RibbonIconButton(
            symbol: "sidebar.left",
            help: isOutlineVisible ? "Hide Outline" : "Show Outline",
            isSelected: isOutlineVisible,
            isToggle: true
        ) {
            withAnimation(ChromeStyle.outlinePanelAnimation) {
                isOutlineVisible.toggle()
            }
        }
    }

    private var fontControlsSection: some View {
        ToolbarSection {
            EditableComboBox(
                text: $selectedFont,
                items: fonts,
                visibleItemCount: 14,
                autofillsCompletion: true,
                previewsFontFamilies: true,
                onCommit: applyFontName
            )
            .frame(width: fontControlWidth, height: ChromeStyle.toolbarControlHeight)
            .help("Font")

            EditableComboBox(
                text: $selectedSizeText,
                items: sizeOptions,
                visibleItemCount: sizeOptions.count,
                onCommit: applyFontSizeText
            )
            .frame(width: ChromeStyle.toolbarSizeControlWidth, height: ChromeStyle.toolbarControlHeight)
            .help("Font Size")

            sizeToolsMenu
        }
    }

    private var primaryInlineFormattingSection: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            inlineTextStyleSection
            ToolbarDivider()
            inlineColorSection
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var inlineTextStyleSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "bold", help: "Bold", isSelected: editor.formattingState.isBold, isToggle: true) {
                editor.toggleBold()
            }

            RibbonIconButton(symbol: "italic", help: "Italic", isSelected: editor.formattingState.isItalic, isToggle: true) {
                editor.toggleItalic()
            }

            RibbonIconButton(symbol: "underline", help: "Underline", isSelected: editor.formattingState.isUnderline, isToggle: true) {
                editor.toggleUnderline()
            }

            RibbonIconButton(
                symbol: "strikethrough",
                help: "Strikethrough",
                isSelected: editor.formattingState.isStrikethrough,
                isToggle: true
            ) {
                editor.toggleStrikethrough()
            }
        }
    }

    private var inlineColorSection: some View {
        ToolbarSection {
            TextColorPaletteButton(
                selectedColor: $textColor,
                customColors: $customTextColors,
                onApplyColor: editor.applyTextColor
            )

            HighlightColorPaletteButton(
                hasHighlight: editor.formattingState.hasHighlight,
                onApplyHighlight: editor.applyHighlight
            )

            RibbonIconButton(symbol: "eraser", help: "Clear Formatting") {
                clearFormatting()
            }
        }
    }

    private func popoverActionRow(
        _ title: String,
        symbol: String,
        isSelected: Bool = false,
        dismiss: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        ToolbarPopoverActionRow(title: title, symbol: symbol, isSelected: isSelected) {
            action()
            dismiss()
        }
    }

    private var sizeToolsMenu: some View {
        ToolbarPopoverButton(title: "Size", symbol: "textformat.size", help: "Text Size Tools", width: 190) { dismiss in
            sizeToolsPopoverContent(dismiss: dismiss)
        }
    }

    @ViewBuilder
    private func sizeToolsPopoverContent(dismiss: @escaping () -> Void) -> some View {
        ToolbarPopoverSection(title: "Size") {
            popoverActionRow("Increase Size", symbol: "textformat.size.larger", dismiss: dismiss) {
                adjustSize(by: 1)
            }

            popoverActionRow("Decrease Size", symbol: "textformat.size.smaller", dismiss: dismiss) {
                adjustSize(by: -1)
            }
        }
    }

    private var stylePresetSection: some View {
        ToolbarSection {
            TextPresetPicker(selection: $selectedStyle, fontName: selectedFont) { preset in
                setSelectedSize(preset.size)
                editor.applyPreset(preset, fontName: selectedFont)
            }
            .frame(width: styleControlWidth, height: ChromeStyle.toolbarControlHeight)
            .chromeGlassControlBackground(
                isActive: true,
                fallbackColor: ChromeStyle.toolbarHoverFill.opacity(0.76),
                in: RoundedRectangle(cornerRadius: ChromeStyle.toolbarPickerCornerRadius, style: .continuous)
            )
        }
    }

    private var fontControlWidth: CGFloat {
        isCompactToolbar ? ChromeStyle.compactToolbarFontControlWidth : ChromeStyle.toolbarFontControlWidth
    }

    private var styleControlWidth: CGFloat {
        isCompactToolbar ? ChromeStyle.compactToolbarStyleControlWidth : ChromeStyle.toolbarStyleControlWidth
    }

    private var toolbarHorizontalPadding: CGFloat {
        isCompactToolbar ? ChromeStyle.compactToolbarHorizontalPadding : ChromeStyle.toolbarHorizontalPadding
    }

    private func adjustSize(by delta: Double) {
        let size = setSelectedSize(selectedSize + delta)
        editor.applyFont(name: selectedFont, size: size)
    }

    private func clearFormatting() {
        selectedFont = "System"
        setSelectedSize(11)
        textColor = .black
        editor.clearFormatting()
    }

    private func applyFontName(_ fontName: String) {
        let trimmedFontName = fontName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFontName.isEmpty else { return }

        selectedFont = trimmedFontName
        editor.applyFont(name: selectedFont, size: selectedSize)
    }

    private func applyFontSizeText(_ text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let size = Double(normalizedText), size.isFinite else {
            selectedSizeText = formattedSize(selectedSize)
            return
        }

        let clampedSize = setSelectedSize(size)
        editor.applyFont(name: selectedFont, size: clampedSize)
    }

    @discardableResult
    private func setSelectedSize(_ size: Double) -> Double {
        let clampedSize = max(6, min(96, size))
        selectedSize = clampedSize
        selectedSizeText = formattedSize(selectedSize)
        return clampedSize
    }

    private func formattedSize(_ size: Double) -> String {
        size.rounded() == size ? "\(Int(size))" : String(format: "%.1f", size)
    }

}

private enum InstalledFontProvider {
    static let fontFamilies: [String] = {
        let families = NSFontManager.shared.availableFontFamilies
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return ["System"] + families
    }()
}

private enum ToolbarAnimationID {
    static let outlineToggle = "outlineToggle"
    static let fontControls = "fontControls"
    static let stylePreset = "stylePreset"
    static let primaryFormatting = "primaryFormatting"
}
