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
    @State private var isMoreMenuHovered = false
    @Namespace private var toolbarNamespace

    private let fonts = InstalledFontProvider.fontFamilies
    private let sizes = [11.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0]

    private var sizeOptions: [String] {
        sizes.map { "\(Int($0))" }
    }

    var body: some View {
        GeometryReader { proxy in
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
            .onAppear {
                updateToolbarMode(for: proxy.size.width, animated: false)
            }
            .onChange(of: proxy.size.width) { width in
                updateToolbarMode(for: width, animated: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isCompactToolbar ? ChromeStyle.compactToolbarHeight : ChromeStyle.regularToolbarHeight)
        .background(.regularMaterial)
    }

    private func updateToolbarMode(for width: CGFloat, animated: Bool) {
        guard width > 0 else { return }
        let shouldUseCompactToolbar: Bool

        if animated {
            shouldUseCompactToolbar = isCompactToolbar
                ? width < ChromeStyle.toolbarRegularBreakpoint
                : width < ChromeStyle.toolbarCompactBreakpoint
        } else {
            shouldUseCompactToolbar = width < ChromeStyle.toolbarModeInitialBreakpoint
        }

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
        }
    }

    private var sizeAdjustmentSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "textformat.size.larger", help: "Increase Font Size") {
                adjustSize(by: 1)
            }

            RibbonIconButton(symbol: "textformat.size.smaller", help: "Decrease Font Size") {
                adjustSize(by: -1)
            }
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

    private var secondaryTextFormattingSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "paintbrush", help: "Highlight", isSelected: editor.formattingState.hasHighlight) {
                editor.toggleHighlight()
            }

            RibbonIconButton(symbol: "eraser", help: "Clear Formatting") {
                selectedFont = "System"
                setSelectedSize(11)
                textColor = .black
                editor.clearFormatting()
            }
        }
    }

    private var regularOverflowFormattingSection: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            sizeAdjustmentSection
            ToolbarDivider()
            secondaryTextFormattingSection
            ToolbarDivider()
            paragraphListSection
            paragraphAlignmentSection
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var paragraphListSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "list.bullet", help: "Bulleted List", isSelected: editor.formattingState.isBulletedList) {
                editor.togglePlainList()
            }

            RibbonIconButton(symbol: "list.number", help: "Numbered List", isSelected: editor.formattingState.isNumberedList) {
                editor.toggleNumberedList()
            }

            RibbonIconButton(symbol: "decrease.indent", help: "Decrease Indent") {
                editor.decreaseIndent()
            }

            RibbonIconButton(symbol: "increase.indent", help: "Increase Indent") {
                editor.increaseIndent()
            }
        }
    }

    private var moreFormattingMenu: some View {
        Menu {
            Section("Text") {
                Button("Increase Size") {
                    adjustSize(by: 1)
                }

                Button("Decrease Size") {
                    adjustSize(by: -1)
                }

                Button {
                    editor.toggleHighlight()
                } label: {
                    menuItemLabel("Highlight", isSelected: editor.formattingState.hasHighlight)
                }

                Button("Clear Formatting") {
                    selectedFont = "System"
                    setSelectedSize(11)
                    textColor = .black
                    editor.clearFormatting()
                }
            }

            Section("Paragraph") {
                Button {
                    editor.togglePlainList()
                } label: {
                    menuItemLabel("Bulleted List", isSelected: editor.formattingState.isBulletedList)
                }

                Button {
                    editor.toggleNumberedList()
                } label: {
                    menuItemLabel("Numbered List", isSelected: editor.formattingState.isNumberedList)
                }

                Button("Decrease Indent") {
                    editor.decreaseIndent()
                }

                Button("Increase Indent") {
                    editor.increaseIndent()
                }
            }

            Section("Alignment") {
                Button {
                    editor.setAlignment(.left)
                } label: {
                    menuItemLabel("Align Left", isSelected: editor.formattingState.alignment == .left)
                }

                Button {
                    editor.setAlignment(.center)
                } label: {
                    menuItemLabel("Align Center", isSelected: editor.formattingState.alignment == .center)
                }

                Button {
                    editor.setAlignment(.right)
                } label: {
                    menuItemLabel("Align Right", isSelected: editor.formattingState.alignment == .right)
                }

                Button {
                    editor.setAlignment(.justified)
                } label: {
                    menuItemLabel("Justify", isSelected: editor.formattingState.alignment == .justified)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(ChromeStyle.controlSymbolFont)
                .foregroundStyle(ChromeStyle.controlTextColor)
                .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isMoreMenuHovered ? ChromeStyle.toolbarHoverFill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            isMoreMenuHovered ? ChromeStyle.toolbarHoverBorder : Color.clear,
                            lineWidth: isMoreMenuHovered ? 1 : 0
                        )
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isMoreMenuHovered = $0 }
        .help("More Formatting")
        .accessibilityLabel("More Formatting")
    }

    private func menuItemLabel(_ title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }

    private var paragraphAlignmentSection: some View {
        ToolbarSection {
            RibbonIconButton(
                symbol: "text.alignleft",
                help: "Align Left",
                isSelected: editor.formattingState.alignment == .left
            ) {
                editor.setAlignment(.left)
            }

            RibbonIconButton(
                symbol: "text.aligncenter",
                help: "Align Center",
                isSelected: editor.formattingState.alignment == .center
            ) {
                editor.setAlignment(.center)
            }

            RibbonIconButton(
                symbol: "text.alignright",
                help: "Align Right",
                isSelected: editor.formattingState.alignment == .right
            ) {
                editor.setAlignment(.right)
            }

            RibbonIconButton(
                symbol: "text.justify",
                help: "Justify",
                isSelected: editor.formattingState.alignment == .justified
            ) {
                editor.setAlignment(.justified)
            }
        }
    }

    private var stylePresetSection: some View {
        ToolbarSection {
            TextPresetPicker(selection: $selectedStyle) { preset in
                setSelectedSize(preset.size)
                editor.applyPreset(preset, fontName: selectedFont)
            }
            .frame(width: styleControlWidth, height: ChromeStyle.toolbarControlHeight)
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
