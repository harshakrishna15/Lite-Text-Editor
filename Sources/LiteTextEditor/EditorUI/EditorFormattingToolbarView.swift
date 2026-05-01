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
                ZStack(alignment: .topLeading) {
                    if isCompactToolbar {
                        compactFormattingBar
                            .transition(.identity)
                    } else {
                        regularFormattingBar
                            .transition(.identity)
                    }
                }
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onAppear {
                updateToolbarMode(for: proxy.size.width, animated: false)
            }
            .onChange(of: proxy.size.width) { width in
                updateToolbarMode(for: width, animated: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var regularFormattingBar: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            outlineToggleButton
                .matchedGeometryEffect(id: ToolbarAnimationID.outlineToggle, in: toolbarNamespace)
            ToolbarDivider()
            fontControlsSection
                .matchedGeometryEffect(id: ToolbarAnimationID.fontControls, in: toolbarNamespace)
            ToolbarDivider()
            stylePresetSection
                .matchedGeometryEffect(id: ToolbarAnimationID.stylePreset, in: toolbarNamespace)
            ToolbarDivider()
            primaryInlineFormattingSection
                .matchedGeometryEffect(id: ToolbarAnimationID.primaryFormatting, in: toolbarNamespace)
            ToolbarDivider()
            regularOverflowFormattingSection
                .matchedGeometryEffect(id: ToolbarAnimationID.overflowFormatting, in: toolbarNamespace)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var compactFormattingBar: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            outlineToggleButton
                .matchedGeometryEffect(id: ToolbarAnimationID.outlineToggle, in: toolbarNamespace)
            ToolbarDivider()
            fontControlsSection
                .matchedGeometryEffect(id: ToolbarAnimationID.fontControls, in: toolbarNamespace)
            ToolbarDivider()
            stylePresetSection
                .matchedGeometryEffect(id: ToolbarAnimationID.stylePreset, in: toolbarNamespace)
            ToolbarDivider()
            primaryInlineFormattingSection
                .matchedGeometryEffect(id: ToolbarAnimationID.primaryFormatting, in: toolbarNamespace)
            ToolbarDivider()
            moreFormattingMenu
                .matchedGeometryEffect(id: ToolbarAnimationID.overflowFormatting, in: toolbarNamespace)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var outlineToggleButton: some View {
        ToolbarSection {
            RibbonIconButton(
                symbol: "sidebar.left",
                help: isOutlineVisible ? "Hide Outline" : "Show Outline",
                isSelected: isOutlineVisible
            ) {
                withAnimation(ChromeStyle.outlinePanelAnimation) {
                    isOutlineVisible.toggle()
                }
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
            .chromeGlassControlBackground(
                isActive: true,
                fallbackColor: ChromeStyle.toolbarHoverFill.opacity(0.76),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .help("Font")

            EditableComboBox(
                text: $selectedSizeText,
                items: sizeOptions,
                visibleItemCount: sizeOptions.count,
                onCommit: applyFontSizeText
            )
            .frame(width: ChromeStyle.toolbarSizeControlWidth, height: ChromeStyle.toolbarControlHeight)
            .chromeGlassControlBackground(
                isActive: true,
                fallbackColor: ChromeStyle.toolbarHoverFill.opacity(0.76),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .help("Font Size")
        }
    }

    private var primaryInlineFormattingSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "bold", help: "Bold", isSelected: editor.formattingState.isBold) {
                editor.toggleBold()
            }

            RibbonIconButton(symbol: "italic", help: "Italic", isSelected: editor.formattingState.isItalic) {
                editor.toggleItalic()
            }

            RibbonIconButton(symbol: "underline", help: "Underline", isSelected: editor.formattingState.isUnderline) {
                editor.toggleUnderline()
            }

            TextColorPaletteButton(
                selectedColor: $textColor,
                customColors: $customTextColors,
                onApplyColor: editor.applyTextColor
            )
        }
    }

    private var regularOverflowFormattingSection: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            textToolsMenu
            paragraphToolsMenu
            listToolsMenu
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var moreFormattingMenu: some View {
        ToolbarMenuButton(title: "More", symbol: "ellipsis.circle", help: "More Formatting") {
            Section("Text") {
                textToolMenuItems
            }

            Section("Paragraph") {
                paragraphToolMenuItems
            }

            Section("Lists") {
                listToolMenuItems
            }
        }
    }

    private func menuIconItemLabel(_ title: String, symbol: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 16, alignment: .center)

            Text(title)

            if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }

    private var textToolsMenu: some View {
        ToolbarMenuButton(title: "Text", symbol: "textformat", help: "Text Formatting") {
            textToolMenuItems
        }
    }

    private var paragraphToolsMenu: some View {
        ToolbarMenuButton(title: "Paragraph", symbol: "text.alignleft", help: "Paragraph Formatting") {
            paragraphToolMenuItems
        }
    }

    private var listToolsMenu: some View {
        ToolbarMenuButton(title: "Lists", symbol: "list.bullet", help: "List Formatting") {
            listToolMenuItems
        }
    }

    @ViewBuilder
    private var textToolMenuItems: some View {
        Button {
            adjustSize(by: 1)
        } label: {
            menuIconItemLabel("Increase Size", symbol: "textformat.size.larger", isSelected: false)
        }

        Button {
            adjustSize(by: -1)
        } label: {
            menuIconItemLabel("Decrease Size", symbol: "textformat.size.smaller", isSelected: false)
        }

        Button {
            editor.toggleHighlight()
        } label: {
            menuIconItemLabel("Highlight", symbol: "paintbrush", isSelected: editor.formattingState.hasHighlight)
        }

        Button {
            selectedFont = "System"
            setSelectedSize(11)
            textColor = .black
            editor.clearFormatting()
        } label: {
            menuIconItemLabel("Clear Formatting", symbol: "eraser", isSelected: false)
        }
    }

    @ViewBuilder
    private var paragraphToolMenuItems: some View {
        Button {
            editor.setAlignment(.left)
        } label: {
            menuIconItemLabel(
                "Left",
                symbol: "text.alignleft",
                isSelected: editor.formattingState.alignment == .left
            )
        }

        Button {
            editor.setAlignment(.center)
        } label: {
            menuIconItemLabel(
                "Center",
                symbol: "text.aligncenter",
                isSelected: editor.formattingState.alignment == .center
            )
        }

        Button {
            editor.setAlignment(.right)
        } label: {
            menuIconItemLabel(
                "Right",
                symbol: "text.alignright",
                isSelected: editor.formattingState.alignment == .right
            )
        }

        Button {
            editor.setAlignment(.justified)
        } label: {
            menuIconItemLabel(
                "Justify",
                symbol: "text.justify",
                isSelected: editor.formattingState.alignment == .justified
            )
        }
    }

    @ViewBuilder
    private var listToolMenuItems: some View {
        Button {
            editor.togglePlainList()
        } label: {
            menuIconItemLabel(
                "Bulleted List",
                symbol: "list.bullet",
                isSelected: editor.formattingState.isBulletedList
            )
        }

        Button {
            editor.toggleNumberedList()
        } label: {
            menuIconItemLabel(
                "Numbered List",
                symbol: "list.number",
                isSelected: editor.formattingState.isNumberedList
            )
        }

        Divider()

        Button {
            editor.decreaseIndent()
        } label: {
            menuIconItemLabel("Decrease Indent", symbol: "decrease.indent", isSelected: false)
        }

        Button {
            editor.increaseIndent()
        } label: {
            menuIconItemLabel("Increase Indent", symbol: "increase.indent", isSelected: false)
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
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
    }

    private var fontControlWidth: CGFloat {
        isCompactToolbar ? ChromeStyle.compactToolbarFontControlWidth : ChromeStyle.toolbarFontControlWidth
    }

    private var styleControlWidth: CGFloat {
        isCompactToolbar ? ChromeStyle.compactToolbarStyleControlWidth : ChromeStyle.toolbarStyleControlWidth
    }

    private func adjustSize(by delta: Double) {
        let size = setSelectedSize(selectedSize + delta)
        editor.applyFont(name: selectedFont, size: size)
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
    static let overflowFormatting = "overflowFormatting"
}
