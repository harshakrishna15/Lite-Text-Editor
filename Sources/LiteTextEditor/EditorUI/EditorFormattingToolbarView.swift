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

            RibbonIconButton(symbol: "strikethrough", help: "Strikethrough") {
                editor.toggleStrikethrough()
            }

            TextColorPaletteButton(
                selectedColor: $textColor,
                customColors: $customTextColors,
                onApplyColor: editor.applyTextColor
            )

            RibbonIconButton(symbol: "paintbrush.pointed", help: "Highlight", isSelected: editor.formattingState.hasHighlight) {
                editor.toggleHighlight()
            }
        }
    }

    private var regularOverflowFormattingSection: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            paragraphQuickFormattingSection
            ToolbarDivider()
            listQuickFormattingSection
            ToolbarDivider()
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
            regularTextToolMenuItems
        }
    }

    private var paragraphToolsMenu: some View {
        ToolbarMenuButton(title: "Paragraph", symbol: "text.alignleft", help: "Paragraph Formatting") {
            regularParagraphToolMenuItems
        }
    }

    private var listToolsMenu: some View {
        ToolbarMenuButton(title: "Lists", symbol: "list.bullet", help: "List Formatting") {
            regularListToolMenuItems
        }
    }

    private var paragraphQuickFormattingSection: some View {
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
                help: "Center",
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

            ToolbarMenuButton(title: "Line Spacing", symbol: "line.3.horizontal", help: "Line Spacing") {
                ForEach(LineSpacingOption.allCases, id: \.rawValue) { option in
                    Button {
                        editor.setLineSpacing(option)
                    } label: {
                        menuIconItemLabel(option.title, symbol: "line.3.horizontal", isSelected: false)
                    }
                }
            }
        }
    }

    private var listQuickFormattingSection: some View {
        ToolbarSection {
            RibbonIconButton(
                symbol: "list.bullet",
                help: "Bulleted List",
                isSelected: editor.formattingState.isBulletedList
            ) {
                editor.togglePlainList()
            }

            RibbonIconButton(
                symbol: "list.number",
                help: "Numbered List",
                isSelected: editor.formattingState.isNumberedList
            ) {
                editor.toggleNumberedList()
            }

            RibbonIconButton(symbol: "decrease.indent", help: "Decrease List Level") {
                editor.decreaseListLevel()
            }

            RibbonIconButton(symbol: "increase.indent", help: "Increase List Level") {
                editor.increaseListLevel()
            }
        }
    }

    @ViewBuilder
    private var regularTextToolMenuItems: some View {
        Menu {
            ForEach(TextBaselineOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.setBaseline(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: baselineSymbol(for: option), isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Baseline", symbol: "textformat.abc", isSelected: false)
        }

        Menu {
            ForEach(HighlightColorOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyHighlight(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: option == .clear ? "xmark.circle" : "paintbrush", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Highlight Color", symbol: "paintbrush.pointed", isSelected: editor.formattingState.hasHighlight)
        }

        Button {
            textColor = .black
            editor.clearTextColor()
        } label: {
            menuIconItemLabel("Clear Text Color", symbol: "textformat", isSelected: false)
        }

        Button {
            editor.copyFormatting()
        } label: {
            menuIconItemLabel("Copy Formatting", symbol: "paintbrush", isSelected: false)
        }

        Button {
            editor.pasteFormatting()
        } label: {
            menuIconItemLabel("Paste Formatting", symbol: "paintbrush.fill", isSelected: false)
        }

        Menu {
            ForEach(TextCasingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyTextCasing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "textformat", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Change Case", symbol: "textformat", isSelected: false)
        }

        Menu {
            ForEach(CharacterSpacingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.setCharacterSpacing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "textformat.size", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Character Spacing", symbol: "textformat.size", isSelected: false)
        }

        Divider()

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
            selectedFont = "System"
            setSelectedSize(11)
            textColor = .black
            editor.clearFormatting()
        } label: {
            menuIconItemLabel("Clear Formatting", symbol: "eraser", isSelected: false)
        }
    }

    @ViewBuilder
    private var textToolMenuItems: some View {
        Button {
            editor.toggleStrikethrough()
        } label: {
            menuIconItemLabel("Strikethrough", symbol: "strikethrough", isSelected: false)
        }

        Menu {
            ForEach(TextBaselineOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.setBaseline(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: baselineSymbol(for: option), isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Baseline", symbol: "textformat.abc", isSelected: false)
        }

        Menu {
            ForEach(HighlightColorOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyHighlight(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: option == .clear ? "xmark.circle" : "paintbrush", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Highlight Color", symbol: "paintbrush.pointed", isSelected: editor.formattingState.hasHighlight)
        }

        Button {
            textColor = .black
            editor.clearTextColor()
        } label: {
            menuIconItemLabel("Clear Text Color", symbol: "textformat", isSelected: false)
        }

        Button {
            editor.copyFormatting()
        } label: {
            menuIconItemLabel("Copy Formatting", symbol: "paintbrush", isSelected: false)
        }

        Button {
            editor.pasteFormatting()
        } label: {
            menuIconItemLabel("Paste Formatting", symbol: "paintbrush.fill", isSelected: false)
        }

        Menu {
            ForEach(TextCasingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyTextCasing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "textformat", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Change Case", symbol: "textformat", isSelected: false)
        }

        Menu {
            ForEach(CharacterSpacingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.setCharacterSpacing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "textformat.size", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Character Spacing", symbol: "textformat.size", isSelected: false)
        }

        Divider()

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
    private var regularParagraphToolMenuItems: some View {
        Menu {
            ForEach(ParagraphSpacingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyParagraphSpacing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "arrow.up.and.down.text.horizontal", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Paragraph Spacing", symbol: "arrow.up.and.down.text.horizontal", isSelected: false)
        }

        Menu {
            ForEach(ParagraphIndentOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyParagraphIndent(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "increase.indent", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Paragraph Indents", symbol: "increase.indent", isSelected: false)
        }

        Button {
            editor.toggleKeepParagraphTogether()
        } label: {
            menuIconItemLabel("Keep Paragraph Together", symbol: "text.badge.checkmark", isSelected: false)
        }

        Button {
            editor.toggleKeepWithNext()
        } label: {
            menuIconItemLabel("Keep With Next", symbol: "text.append", isSelected: false)
        }

        Divider()

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
    private var paragraphToolMenuItems: some View {
        Menu {
            ForEach(LineSpacingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.setLineSpacing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "line.3.horizontal", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Line Spacing", symbol: "line.3.horizontal", isSelected: false)
        }

        Menu {
            ForEach(ParagraphSpacingOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyParagraphSpacing(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "arrow.up.and.down.text.horizontal", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Paragraph Spacing", symbol: "arrow.up.and.down.text.horizontal", isSelected: false)
        }

        Menu {
            ForEach(ParagraphIndentOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyParagraphIndent(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: "increase.indent", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Paragraph Indents", symbol: "increase.indent", isSelected: false)
        }

        Button {
            editor.toggleKeepParagraphTogether()
        } label: {
            menuIconItemLabel("Keep Paragraph Together", symbol: "text.badge.checkmark", isSelected: false)
        }

        Button {
            editor.toggleKeepWithNext()
        } label: {
            menuIconItemLabel("Keep With Next", symbol: "text.append", isSelected: false)
        }

        Divider()

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
    private var regularListToolMenuItems: some View {
        Menu {
            ForEach([ListStyleOption.lettered, .roman, .checklist], id: \.rawValue) { option in
                Button {
                    editor.applyListStyle(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: listSymbol(for: option), isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("More List Styles", symbol: "list.bullet", isSelected: false)
        }

        Menu {
            ForEach(ListNumberingAction.allCases, id: \.rawValue) { action in
                Button {
                    editor.applyListNumberingAction(action)
                } label: {
                    menuIconItemLabel(action.title, symbol: "list.number", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Numbering", symbol: "list.number", isSelected: false)
        }
    }

    @ViewBuilder
    private var listToolMenuItems: some View {
        Menu {
            ForEach(ListStyleOption.allCases, id: \.rawValue) { option in
                Button {
                    editor.applyListStyle(option)
                } label: {
                    menuIconItemLabel(option.title, symbol: listSymbol(for: option), isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("List Style", symbol: "list.bullet", isSelected: false)
        }

        Button {
            editor.toggleChecklist()
        } label: {
            menuIconItemLabel("Checklist", symbol: "checklist", isSelected: false)
        }

        Menu {
            ForEach(ListNumberingAction.allCases, id: \.rawValue) { action in
                Button {
                    editor.applyListNumberingAction(action)
                } label: {
                    menuIconItemLabel(action.title, symbol: "list.number", isSelected: false)
                }
            }
        } label: {
            menuIconItemLabel("Numbering", symbol: "list.number", isSelected: false)
        }

        Divider()

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
            editor.decreaseListLevel()
        } label: {
            menuIconItemLabel("Decrease List Level", symbol: "decrease.indent", isSelected: false)
        }

        Button {
            editor.increaseListLevel()
        } label: {
            menuIconItemLabel("Increase List Level", symbol: "increase.indent", isSelected: false)
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

    private func baselineSymbol(for option: TextBaselineOption) -> String {
        switch option {
        case .normal:
            return "textformat.abc"
        case .superscript:
            return "textformat.superscript"
        case .subscript:
            return "textformat.subscript"
        }
    }

    private func listSymbol(for option: ListStyleOption) -> String {
        switch option {
        case .bullet, .dash:
            return "list.bullet"
        case .numbered, .lettered, .roman:
            return "list.number"
        case .checklist:
            return "checklist"
        }
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
