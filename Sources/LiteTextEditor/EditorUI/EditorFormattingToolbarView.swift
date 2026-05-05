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
        .background(ChromeBlurBackground())
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
            ToolbarDivider()
            overflowFormattingSection
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .fixedSize(horizontal: true, vertical: false)
        .animation(ChromeStyle.toolbarModeAnimation, value: isCompactToolbar)
    }

    private var overflowFormattingSection: some View {
        ZStack(alignment: .leading) {
            if isCompactToolbar {
                moreFormattingMenu
                    .matchedGeometryEffect(id: ToolbarAnimationID.overflowFormatting, in: toolbarNamespace)
                    .transition(toolbarOverflowTransition)
            } else {
                regularOverflowFormattingSection
                    .matchedGeometryEffect(id: ToolbarAnimationID.overflowFormatting, in: toolbarNamespace)
                    .transition(toolbarOverflowTransition)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .clipped()
    }

    private var toolbarOverflowTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .leading)),
            removal: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .leading))
        )
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

    private var regularOverflowFormattingSection: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            paragraphQuickFormattingSection
            ToolbarDivider()
            listQuickFormattingSection
            ToolbarDivider()
            expandedToolsSection
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var moreFormattingMenu: some View {
        ToolbarPopoverButton(title: "More", symbol: "ellipsis.circle", help: "More Formatting", width: 286) { dismiss in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    textToolsPopoverContent(
                        dismiss: dismiss,
                        includesCompactOnlyItems: false,
                        includesSizeAndClearTools: false
                    )
                    Divider()
                    paragraphToolsPopoverContent(
                        dismiss: dismiss,
                        includesAlignment: true,
                        includesLineSpacing: true,
                        includesAlignmentTools: true
                    )
                    Divider()
                    listToolsPopoverContent(dismiss: dismiss, includesPrimaryListActions: true)
                }
            }
            .frame(maxHeight: 480)
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

    private var textToolsMenu: some View {
        ToolbarPopoverButton(title: "Text", symbol: "textformat", help: "Text Formatting", width: 260) { dismiss in
            textToolsPopoverContent(
                dismiss: dismiss,
                includesCompactOnlyItems: false,
                includesSizeAndClearTools: false
            )
        }
    }

    private var expandedToolsSection: some View {
        ToolbarSection {
            textToolsMenu
            paragraphToolsMenu
            listToolsMenu
        }
    }

    private var sizeToolsMenu: some View {
        ToolbarPopoverButton(title: "Size", symbol: "textformat.size", help: "Text Size Tools", width: 190) { dismiss in
            sizeToolsPopoverContent(dismiss: dismiss)
        }
    }

    private var paragraphToolsMenu: some View {
        ToolbarPopoverButton(title: "Paragraph", symbol: "text.alignleft", help: "Paragraph Formatting", width: 264) { dismiss in
            paragraphToolsPopoverContent(
                dismiss: dismiss,
                includesAlignment: false,
                includesLineSpacing: false,
                includesAlignmentTools: false
            )
        }
    }

    private var listToolsMenu: some View {
        ToolbarPopoverButton(title: "Lists", symbol: "list.bullet", help: "List Formatting", width: 232) { dismiss in
            listToolsPopoverContent(dismiss: dismiss, includesPrimaryListActions: false)
        }
    }

    private var paragraphQuickFormattingSection: some View {
        ToolbarSection {
            RibbonIconButton(
                symbol: "text.alignleft",
                help: "Align Left",
                isSelected: editor.formattingState.alignment == .left,
                isToggle: true
            ) {
                editor.setAlignment(.left)
            }

            RibbonIconButton(
                symbol: "text.aligncenter",
                help: "Center",
                isSelected: editor.formattingState.alignment == .center,
                isToggle: true
            ) {
                editor.setAlignment(.center)
            }

            RibbonIconButton(
                symbol: "text.alignright",
                help: "Align Right",
                isSelected: editor.formattingState.alignment == .right,
                isToggle: true
            ) {
                editor.setAlignment(.right)
            }

            RibbonIconButton(
                symbol: "text.justify",
                help: "Justify",
                isSelected: editor.formattingState.alignment == .justified,
                isToggle: true
            ) {
                editor.setAlignment(.justified)
            }

            ToolbarPopoverButton(title: "Line Spacing", symbol: "line.3.horizontal", help: "Line Spacing", width: 150) { dismiss in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(LineSpacingOption.allCases, id: \.rawValue) { option in
                        popoverActionRow(option.title, symbol: "line.3.horizontal", dismiss: dismiss) {
                            editor.setLineSpacing(option)
                        }
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
                isSelected: editor.formattingState.isBulletedList,
                isToggle: true
            ) {
                editor.togglePlainList()
            }

            RibbonIconButton(
                symbol: "list.number",
                help: "Numbered List",
                isSelected: editor.formattingState.isNumberedList,
                isToggle: true
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
    private func textToolsPopoverContent(
        dismiss: @escaping () -> Void,
        includesCompactOnlyItems: Bool,
        includesSizeAndClearTools: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolbarPopoverSection(title: "Baseline") {
                ForEach(TextBaselineOption.allCases, id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: baselineSymbol(for: option), dismiss: dismiss) {
                        editor.setBaseline(option)
                    }
                }
            }

            ToolbarPopoverSection(title: "Text Tools") {
                if includesCompactOnlyItems {
                    popoverActionRow(
                        "Strikethrough",
                        symbol: "strikethrough",
                        dismiss: dismiss
                    ) {
                        editor.toggleStrikethrough()
                    }
                }

                popoverActionRow("Clear Text Color", symbol: "textformat", dismiss: dismiss) {
                    textColor = .black
                    editor.clearTextColor()
                }

                popoverActionRow("Copy Formatting", symbol: "paintbrush", dismiss: dismiss) {
                    editor.copyFormatting()
                }

                popoverActionRow("Paste Formatting", symbol: "paintbrush.fill", dismiss: dismiss) {
                    editor.pasteFormatting()
                }
            }

            ToolbarPopoverSection(title: "Change Case") {
                ForEach(TextCasingOption.allCases, id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: "textformat", dismiss: dismiss) {
                        editor.applyTextCasing(option)
                    }
                }
            }

            ToolbarPopoverSection(title: "Character Spacing") {
                ForEach(CharacterSpacingOption.allCases, id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: "textformat.size", dismiss: dismiss) {
                        editor.setCharacterSpacing(option)
                    }
                }
            }

            if includesSizeAndClearTools {
                Divider()

                sizeToolsPopoverContent(dismiss: dismiss)
                clearFormattingPopoverContent(dismiss: dismiss)
            }
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

    @ViewBuilder
    private func clearFormattingPopoverContent(dismiss: @escaping () -> Void) -> some View {
        ToolbarPopoverSection(title: "Formatting") {
            popoverActionRow("Clear Formatting", symbol: "eraser", dismiss: dismiss) {
                clearFormatting()
            }
        }
    }

    @ViewBuilder
    private func paragraphToolsPopoverContent(
        dismiss: @escaping () -> Void,
        includesAlignment: Bool,
        includesLineSpacing: Bool,
        includesAlignmentTools: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if includesLineSpacing {
                ToolbarPopoverSection(title: "Line Spacing") {
                    ForEach(LineSpacingOption.allCases, id: \.rawValue) { option in
                        popoverActionRow(option.title, symbol: "line.3.horizontal", dismiss: dismiss) {
                            editor.setLineSpacing(option)
                        }
                    }
                }
            }

            ToolbarPopoverSection(title: "Paragraph Spacing") {
                ForEach(ParagraphSpacingOption.allCases, id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: "arrow.up.and.down.text.horizontal", dismiss: dismiss) {
                        editor.applyParagraphSpacing(option)
                    }
                }
            }

            ToolbarPopoverSection(title: "Indents") {
                ForEach(ParagraphIndentOption.allCases, id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: "increase.indent", dismiss: dismiss) {
                        editor.applyParagraphIndent(option)
                    }
                }
            }

            ToolbarPopoverSection(title: "Keep Options") {
                popoverActionRow("Keep Paragraph Together", symbol: "text.badge.checkmark", dismiss: dismiss) {
                    editor.toggleKeepParagraphTogether()
                }

                popoverActionRow("Keep With Next", symbol: "text.append", dismiss: dismiss) {
                    editor.toggleKeepWithNext()
                }
            }

            if includesAlignmentTools {
                Divider()

                alignmentToolsPopoverContent(dismiss: dismiss, includesPrimaryAlignment: includesAlignment)
            }
        }
    }

    @ViewBuilder
    private func alignmentToolsPopoverContent(
        dismiss: @escaping () -> Void,
        includesPrimaryAlignment: Bool
    ) -> some View {
        ToolbarPopoverSection(title: "Alignment") {
            if includesPrimaryAlignment {
                popoverActionRow(
                    "Left",
                    symbol: "text.alignleft",
                    isSelected: editor.formattingState.alignment == .left,
                    dismiss: dismiss
                ) {
                    editor.setAlignment(.left)
                }

                popoverActionRow(
                    "Center",
                    symbol: "text.aligncenter",
                    isSelected: editor.formattingState.alignment == .center,
                    dismiss: dismiss
                ) {
                    editor.setAlignment(.center)
                }

                popoverActionRow(
                    "Right",
                    symbol: "text.alignright",
                    isSelected: editor.formattingState.alignment == .right,
                    dismiss: dismiss
                ) {
                    editor.setAlignment(.right)
                }
            }

            popoverActionRow(
                "Justify",
                symbol: "text.justify",
                isSelected: editor.formattingState.alignment == .justified,
                dismiss: dismiss
            ) {
                editor.setAlignment(.justified)
            }
        }
    }

    @ViewBuilder
    private func listToolsPopoverContent(
        dismiss: @escaping () -> Void,
        includesPrimaryListActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolbarPopoverSection(title: "List Style") {
                ForEach(includesPrimaryListActions ? ListStyleOption.allCases : [ListStyleOption.lettered, .roman, .checklist], id: \.rawValue) { option in
                    popoverActionRow(option.title, symbol: listSymbol(for: option), dismiss: dismiss) {
                        editor.applyListStyle(option)
                    }
                }
            }

            if includesPrimaryListActions {
                ToolbarPopoverSection(title: "Lists") {
                    popoverActionRow(
                        "Bulleted List",
                        symbol: "list.bullet",
                        isSelected: editor.formattingState.isBulletedList,
                        dismiss: dismiss
                    ) {
                        editor.togglePlainList()
                    }

                    popoverActionRow(
                        "Numbered List",
                        symbol: "list.number",
                        isSelected: editor.formattingState.isNumberedList,
                        dismiss: dismiss
                    ) {
                        editor.toggleNumberedList()
                    }

                    popoverActionRow("Checklist", symbol: "checklist", dismiss: dismiss) {
                        editor.toggleChecklist()
                    }
                }

                ToolbarPopoverSection(title: "List Level") {
                    popoverActionRow("Decrease List Level", symbol: "decrease.indent", dismiss: dismiss) {
                        editor.decreaseListLevel()
                    }

                    popoverActionRow("Increase List Level", symbol: "increase.indent", dismiss: dismiss) {
                        editor.increaseListLevel()
                    }
                }
            }

            ToolbarPopoverSection(title: "Numbering") {
                ForEach(ListNumberingAction.allCases, id: \.rawValue) { action in
                    popoverActionRow(action.title, symbol: "list.number", dismiss: dismiss) {
                        editor.applyListNumberingAction(action)
                    }
                }
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
