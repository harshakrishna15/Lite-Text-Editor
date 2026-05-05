import AppKit
import CoreText
import SwiftUI

extension NSAttributedString.Key {
    static let liteTextEditorKeepParagraphTogether = NSAttributedString.Key("liteTextEditorKeepParagraphTogether")
    static let liteTextEditorKeepWithNext = NSAttributedString.Key("liteTextEditorKeepWithNext")
    static let liteTextEditorSmallCaps = NSAttributedString.Key("liteTextEditorSmallCaps")
}

extension EditorController {
    func scheduleFormattingStateRefresh() {
        pendingFormattingStateRefresh?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingFormattingStateRefresh = nil
            self?.refreshFormattingState()
        }

        pendingFormattingStateRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: workItem)
    }

    func refreshFormattingState() {
        pendingFormattingStateRefresh?.cancel()
        pendingFormattingStateRefresh = nil

        guard let textView else {
            if formattingState != FormattingState() {
                formattingState = FormattingState()
            }
            return
        }

        let nextState = currentFormattingState(in: textView)

        if nextState != formattingState {
            formattingState = nextState
        }

        refreshActiveOutlineItem()
    }

    func toggleBold() {
        toggleFontTrait(.bold)
    }

    func toggleItalic() {
        toggleFontTrait(.italic)
    }

    func toggleUnderline() {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()
        let style = NSUnderlineStyle.single.rawValue

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Underline") { textStorage, editRange in
                let hasUnderline = textStorage.attribute(.underlineStyle, at: editRange.location, effectiveRange: nil) != nil

                if hasUnderline {
                    textStorage.removeAttribute(.underlineStyle, range: editRange)
                } else {
                    textStorage.addAttribute(.underlineStyle, value: style, range: editRange)
                }

                return true
            }
        } else {
            if textView.typingAttributes[.underlineStyle] != nil {
                textView.typingAttributes.removeValue(forKey: .underlineStyle)
            } else {
                textView.typingAttributes[.underlineStyle] = style
            }
        }

        refreshFormattingState()
    }

    func toggleStrikethrough() {
        toggleAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            actionName: "Strikethrough"
        )
    }

    func setBaseline(_ option: TextBaselineOption) {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: option.title) { textStorage, editRange in
                if option == .normal {
                    textStorage.removeAttribute(.baselineOffset, range: editRange)
                    textStorage.removeAttribute(.superscript, range: editRange)
                } else {
                    textStorage.addAttribute(.superscript, value: option.offset, range: editRange)
                    textStorage.addAttribute(.baselineOffset, value: CGFloat(option.offset) * 4, range: editRange)
                }
                return true
            }
        } else {
            if option == .normal {
                textView.typingAttributes.removeValue(forKey: .baselineOffset)
                textView.typingAttributes.removeValue(forKey: .superscript)
            } else {
                textView.typingAttributes[.superscript] = option.offset
                textView.typingAttributes[.baselineOffset] = CGFloat(option.offset) * 4
            }
        }

        refreshFormattingState()
    }

    func applyPreset(_ preset: TextPreset, fontName: String) {
        guard let textView else { return }
        let font = makeFont(name: fontName, size: preset.size, weight: preset.weight)
        let range = textView.selectedRange().length == 0 && !textView.string.isEmpty
            ? textView.effectiveParagraphRangeForFormatting()
            : textView.effectiveRangeForFormatting()
        let paragraphStyle = paragraphStyle(for: preset, in: textView)

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: preset.title) { textStorage, editRange in
                textStorage.addAttributes(
                    [
                        .font: font,
                        .paragraphStyle: paragraphStyle
                    ],
                    range: editRange
                )
                return true
            }
        } else {
            textView.typingAttributes[.font] = font
            textView.typingAttributes[.paragraphStyle] = paragraphStyle
        }

        refreshOutlineItems()
        refreshFormattingState()
    }

    func applyPresetUsingCurrentFont(_ preset: TextPreset) {
        applyPreset(preset, fontName: currentFontFamilyNameForFormatting())
    }

    func applyFont(name: String, size: Double) {
        let font = makeFont(name: name, size: size, weight: .regular)
        applyFont(font)
    }

    func applyTextColor(_ color: Color) {
        guard let textView else { return }
        let nsColor = NSColor(color)
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Text Color") { textStorage, editRange in
                textStorage.addAttribute(.foregroundColor, value: nsColor, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes[.foregroundColor] = nsColor
        }

        refreshFormattingState()
    }

    func clearTextColor() {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Clear Text Color") { textStorage, editRange in
                textStorage.removeAttribute(.foregroundColor, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes.removeValue(forKey: .foregroundColor)
        }

        refreshFormattingState()
    }

    func toggleHighlight() {
        guard let textView else { return }
        let attributes = representativeFormattingAttributes(in: textView)
        applyHighlight(attributes[.backgroundColor] == nil ? .yellow : .clear)
    }

    func applyHighlight(_ option: HighlightColorOption) {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: option.title) { textStorage, editRange in
                if let color = option.color {
                    textStorage.addAttribute(.backgroundColor, value: color, range: editRange)
                } else {
                    textStorage.removeAttribute(.backgroundColor, range: editRange)
                }
                return true
            }
        } else {
            if let color = option.color {
                textView.typingAttributes[.backgroundColor] = color
            } else {
                textView.typingAttributes.removeValue(forKey: .backgroundColor)
            }
        }

        refreshFormattingState()
    }

    func copyFormatting() {
        guard let textView else { return }
        copiedFormattingAttributes = representativeFormattingAttributes(in: textView)
    }

    func pasteFormatting() {
        guard let textView, let copiedFormattingAttributes else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Paste Formatting") { textStorage, editRange in
                textStorage.addAttributes(copiedFormattingAttributes, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes.merge(copiedFormattingAttributes) { _, new in new }
        }

        refreshFormattingState()
    }

    func applyTextCasing(_ option: TextCasingOption) {
        if option == .smallCaps {
            applySmallCaps()
            return
        }

        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()
        guard range.length > 0 else { return }

        let original = (textView.string as NSString).substring(with: range)
        let transformed: String

        switch option {
        case .uppercase:
            transformed = original.uppercased()
        case .lowercase:
            transformed = original.lowercased()
        case .capitalizeWords:
            transformed = original.capitalized
        case .smallCaps:
            transformed = original
        }

        guard transformed != original,
              textView.shouldChangeText(in: range, replacementString: transformed) else { return }

        textView.textStorage?.replaceCharacters(in: range, with: transformed)
        textView.didChangeText()
        textView.undoManager?.setActionName(option.title)
        textView.breakUndoCoalescing()
        refreshFormattingState()
    }

    private func applySmallCaps() {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()
        let featureSettings: [[NSFontDescriptor.FeatureKey: Int]] = [
            [
                .typeIdentifier: kLowerCaseType,
                .selectorIdentifier: kLowerCaseSmallCapsSelector
            ]
        ]

        let makeSmallCapsFont: (NSFont) -> NSFont = { font in
            let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: featureSettings])
            return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        }

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Small Caps") { textStorage, editRange in
                var updates: [(NSRange, NSFont)] = []

                textStorage.enumerateAttribute(.font, in: editRange) { value, effectiveRange, _ in
                    let font = value as? NSFont ?? NSFont.systemFont(ofSize: 11)
                    updates.append((effectiveRange, makeSmallCapsFont(font)))
                }

                updates.forEach { update in
                    textStorage.addAttribute(.font, value: update.1, range: update.0)
                }
                textStorage.addAttribute(.liteTextEditorSmallCaps, value: true, range: editRange)

                return !updates.isEmpty
            }
        } else {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 11)
            textView.typingAttributes[.font] = makeSmallCapsFont(font)
            textView.typingAttributes[.liteTextEditorSmallCaps] = true
        }

        refreshFormattingState()
    }

    func setCharacterSpacing(_ option: CharacterSpacingOption) {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Character Spacing") { textStorage, editRange in
                if let kern = option.kern {
                    textStorage.addAttribute(.kern, value: kern, range: editRange)
                } else {
                    textStorage.removeAttribute(.kern, range: editRange)
                }
                return true
            }
        } else if let kern = option.kern {
            textView.typingAttributes[.kern] = kern
        } else {
            textView.typingAttributes.removeValue(forKey: .kern)
        }

        refreshFormattingState()
    }

    func clearFormatting() {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()
        let defaultFont = NSFont.systemFont(ofSize: 11)

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Clear Formatting") { textStorage, editRange in
                textStorage.addAttribute(.font, value: defaultFont, range: editRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.black, range: editRange)
                textStorage.removeAttribute(.underlineStyle, range: editRange)
                textStorage.removeAttribute(.backgroundColor, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes[.font] = defaultFont
            textView.typingAttributes[.foregroundColor] = NSColor.black
            textView.typingAttributes.removeValue(forKey: .underlineStyle)
            textView.typingAttributes.removeValue(forKey: .backgroundColor)
        }

        refreshFormattingState()
    }

    func setAlignment(_ alignment: NSTextAlignment) {
        guard let textView else { return }
        var didUpdateAlignment = false

        textView.preservingVisibleOrigin {
            if textView.string.isEmpty {
                let paragraphStyle = (textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?
                    .mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
                guard paragraphStyle.alignment != alignment else { return }
                paragraphStyle.alignment = alignment
                textView.typingAttributes[.paragraphStyle] = paragraphStyle
            } else {
                didUpdateAlignment = textView.setSelectedParagraphAlignment(alignment)
            }
        }

        if didUpdateAlignment {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func setLineSpacing(_ option: LineSpacingOption) {
        updateSelectedParagraphStyle(actionName: "Line Spacing") { paragraphStyle in
            paragraphStyle.lineHeightMultiple = option.multiple
            paragraphStyle.lineSpacing = 0
        }
    }

    func applyParagraphSpacing(_ option: ParagraphSpacingOption) {
        updateSelectedParagraphStyle(actionName: option.title) { paragraphStyle in
            switch option {
            case .before:
                paragraphStyle.paragraphSpacingBefore = 8
            case .after:
                paragraphStyle.paragraphSpacing = 8
            case .remove:
                paragraphStyle.paragraphSpacingBefore = 0
                paragraphStyle.paragraphSpacing = 0
            }
        }
    }

    func applyParagraphIndent(_ option: ParagraphIndentOption) {
        updateSelectedParagraphStyle(actionName: option.title) { paragraphStyle in
            switch option {
            case .firstLine:
                paragraphStyle.firstLineHeadIndent = 36
                paragraphStyle.headIndent = 0
            case .hanging:
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 36
            case .clear:
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 0
            }
        }
    }

    func toggleKeepParagraphTogether() {
        toggleAttribute(
            .liteTextEditorKeepParagraphTogether,
            value: true,
            actionName: "Keep Paragraph Together",
            paragraphScoped: true
        )
    }

    func toggleKeepWithNext() {
        toggleAttribute(
            .liteTextEditorKeepWithNext,
            value: true,
            actionName: "Keep With Next",
            paragraphScoped: true
        )
    }

    func togglePlainList() {
        guard let textView else { return }
        if textView.toggleListStyle(.bullet) {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func toggleNumberedList() {
        guard let textView else { return }
        if textView.toggleListStyle(.numbered) {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func toggleChecklist() {
        applyListStyle(.checklist)
    }

    func applyListStyle(_ option: ListStyleOption) {
        guard let textView else { return }
        if textView.toggleListStyle(option) {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func applyListNumberingAction(_ action: ListNumberingAction) {
        guard let textView else { return }
        let didEdit: Bool

        switch action {
        case .restart:
            didEdit = textView.restartNumberedList()
        case .continue:
            didEdit = textView.continueNumberedList()
        }

        if didEdit {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func increaseIndent() {
        guard let textView else { return }
        if textView.increasePlainIndent() {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func decreaseIndent() {
        guard let textView else { return }
        if textView.decreasePlainIndent() {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func increaseListLevel() {
        increaseIndent()
    }

    func decreaseListLevel() {
        decreaseIndent()
    }

    private func toggleAttribute(
        _ attribute: NSAttributedString.Key,
        value: Any,
        actionName: String,
        paragraphScoped: Bool = false
    ) {
        guard let textView else { return }
        let range = paragraphScoped ? textView.effectiveParagraphRangeForFormatting() : textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: actionName) { textStorage, editRange in
                if textStorage.attribute(attribute, at: editRange.location, effectiveRange: nil) != nil {
                    textStorage.removeAttribute(attribute, range: editRange)
                } else {
                    textStorage.addAttribute(attribute, value: value, range: editRange)
                }
                return true
            }
        } else if textView.typingAttributes[attribute] != nil {
            textView.typingAttributes.removeValue(forKey: attribute)
        } else {
            textView.typingAttributes[attribute] = value
        }

        refreshFormattingState()
    }

    private func updateSelectedParagraphStyle(
        actionName: String,
        _ update: (NSMutableParagraphStyle) -> Void
    ) {
        guard let textView else { return }
        let paragraphRange = textView.effectiveParagraphRangeForFormatting()
        let baseStyle = currentParagraphStyle(in: textView).mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()
        update(baseStyle)

        if paragraphRange.length > 0 {
            textView.performUndoableAttributeEdit(in: paragraphRange, actionName: actionName) { textStorage, editRange in
                textStorage.addAttribute(.paragraphStyle, value: baseStyle, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes[.paragraphStyle] = baseStyle
        }

        refreshFormattingState()
    }

    private func applyFont(_ font: NSFont, range requestedRange: NSRange? = nil) {
        guard let textView else { return }
        let range = requestedRange ?? textView.effectiveRangeForFormatting()

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Font") { textStorage, editRange in
                textStorage.addAttribute(.font, value: font, range: editRange)
                return true
            }
        } else {
            textView.typingAttributes[.font] = font
        }

        refreshOutlineItems()
        refreshFormattingState()
    }

    private func toggleFontTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()

        if range.length > 0 {
            let actionName = trait == .bold ? "Bold" : "Italic"
            textView.performUndoableAttributeEdit(in: range, actionName: actionName) { textStorage, editRange in
                var updates: [(range: NSRange, font: NSFont)] = []

                textStorage.enumerateAttribute(.font, in: editRange) { value, effectiveRange, _ in
                    let font = value as? NSFont ?? NSFont.systemFont(ofSize: 11)
                    updates.append((effectiveRange, font.togglingSymbolicTrait(trait)))
                }

                updates.forEach { update in
                    textStorage.addAttribute(.font, value: update.font, range: update.range)
                }

                return !updates.isEmpty
            }
        } else {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 11)
            textView.typingAttributes[.font] = font.togglingSymbolicTrait(trait)
        }

        refreshFormattingState()
    }

    private func currentFormattingState(in textView: AutocompleteTextView) -> FormattingState {
        let attributes = representativeFormattingAttributes(in: textView)
        let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 11)
        let traits = font.fontDescriptor.symbolicTraits
        let listState = currentListState(in: textView)

        return FormattingState(
            fontFamilyName: displayFontFamilyName(for: font),
            fontSize: Double(font.pointSize),
            textColor: attributes[.foregroundColor] as? NSColor ?? NSColor.black,
            isBold: traits.contains(.bold),
            isItalic: traits.contains(.italic),
            isUnderline: attributes[.underlineStyle] != nil,
            hasHighlight: attributes[.backgroundColor] != nil,
            isBulletedList: listState.isBulleted,
            isNumberedList: listState.isNumbered,
            alignment: normalizedAlignment(currentParagraphStyle(in: textView).alignment)
        )
    }

    private func representativeFormattingAttributes(in textView: AutocompleteTextView) -> [NSAttributedString.Key: Any] {
        let selection = textView.selectedRange()

        guard let textStorage = textView.textStorage,
              textStorage.length > 0 else {
            return textView.typingAttributes
        }

        let sampleLocation: Int
        if selection.length > 0 {
            sampleLocation = selection.location
        } else if let formattingSampleLocation = textView.formattingSampleLocation {
            sampleLocation = formattingSampleLocation
        } else if selection.location >= textStorage.length {
            sampleLocation = textStorage.length - 1
        } else {
            sampleLocation = selection.location
        }

        let location = min(max(sampleLocation, 0), textStorage.length - 1)
        return textStorage.attributes(at: location, effectiveRange: nil)
    }

    private func currentParagraphStyle(in textView: AutocompleteTextView) -> NSParagraphStyle {
        if let textStorage = textView.textStorage, textStorage.length > 0 {
            let selection = textView.selectedRange()
            let sampleLocation: Int
            if selection.length > 0 {
                sampleLocation = selection.location
            } else if let formattingSampleLocation = textView.formattingSampleLocation {
                sampleLocation = formattingSampleLocation
            } else {
                sampleLocation = selection.location >= textStorage.length ? textStorage.length - 1 : selection.location
            }
            let location = min(max(sampleLocation, 0), textStorage.length - 1)

            if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle {
                return paragraphStyle
            }
        }

        return textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
            ?? textView.defaultParagraphStyle
            ?? NSParagraphStyle.default
    }

    private func paragraphStyle(for preset: TextPreset, in textView: AutocompleteTextView) -> NSParagraphStyle {
        let paragraphStyle = currentParagraphStyle(in: textView).mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()

        paragraphStyle.paragraphSpacingBefore = preset.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = preset.paragraphSpacingAfter
        paragraphStyle.lineHeightMultiple = preset.lineHeightMultiple

        return paragraphStyle
    }

    private func currentListState(in textView: AutocompleteTextView) -> (isBulleted: Bool, isNumbered: Bool) {
        let nsString = textView.string as NSString
        guard nsString.length > 0 else { return (false, false) }

        let documentRange = NSRange(location: 0, length: nsString.length)
        let paragraphRange = NSIntersectionRange(textView.effectiveParagraphRangeForFormatting(), documentRange)
        guard paragraphRange.location != NSNotFound, paragraphRange.length > 0 else {
            return (false, false)
        }

        var hasListCandidateLine = false
        var allBulleted = true
        var allNumbered = true

        nsString.enumerateSubstrings(in: paragraphRange, options: [.byLines]) { substring, _, _, _ in
            guard let line = substring?.trimmingCharacters(in: .whitespaces),
                  !line.isEmpty else {
                return
            }

            hasListCandidateLine = true
            allBulleted = allBulleted && line.hasPrefix("- ")
            allNumbered = allNumbered && self.lineStartsWithNumberedListMarker(line)
        }

        guard hasListCandidateLine else { return (false, false) }
        return (allBulleted, allNumbered)
    }

    private func lineStartsWithNumberedListMarker(_ line: String) -> Bool {
        var index = line.startIndex
        var sawDigit = false

        while index < line.endIndex, line[index].isNumber {
            sawDigit = true
            index = line.index(after: index)
        }

        guard sawDigit, index < line.endIndex, line[index] == "." else { return false }
        index = line.index(after: index)
        return index < line.endIndex && line[index] == " "
    }

    private func normalizedAlignment(_ alignment: NSTextAlignment) -> NSTextAlignment {
        alignment == .natural ? .left : alignment
    }

    private func displayFontFamilyName(for font: NSFont) -> String {
        SystemFontName.displayName(for: font)
    }

    private func makeFont(name: String, size: Double, weight: NSFont.Weight) -> NSFont {
        if SystemFontName.isSystemDisplayName(name) {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }

        let traits: NSFontTraitMask = weight == .regular ? [] : [.boldFontMask]
        let fontManager = NSFontManager.shared

        return fontManager.font(
            withFamily: name,
            traits: traits,
            weight: fontManagerWeight(for: weight),
            size: size
        ) ?? fontManager.font(
            withFamily: name,
            traits: [],
            weight: 5,
            size: size
        ) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    private func fontManagerWeight(for weight: NSFont.Weight) -> Int {
        switch weight {
        case .ultraLight, .thin:
            return 2
        case .light:
            return 3
        case .regular:
            return 5
        case .medium:
            return 6
        case .semibold:
            return 8
        case .bold, .heavy, .black:
            return 9
        default:
            return 5
        }
    }

    private func currentFontFamilyNameForFormatting() -> String {
        guard let textView else { return "System" }
        let attributes = representativeFormattingAttributes(in: textView)
        guard let font = attributes[.font] as? NSFont,
              let familyName = font.familyName,
              !familyName.isEmpty else {
            return "System"
        }

        return SystemFontName.isSystemFont(font)
            ? SystemFontName.displayName
            : familyName
    }
}

private extension NSFont {
    func togglingSymbolicTrait(_ trait: NSFontDescriptor.SymbolicTraits) -> NSFont {
        var traits = fontDescriptor.symbolicTraits

        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }

        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
