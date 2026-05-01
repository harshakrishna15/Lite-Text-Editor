import AppKit
import SwiftUI

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

    func toggleHighlight() {
        guard let textView else { return }
        let range = textView.effectiveRangeForFormatting()
        let highlightColor = NSColor.systemYellow.withAlphaComponent(0.45)

        if range.length > 0 {
            textView.performUndoableAttributeEdit(in: range, actionName: "Highlight") { textStorage, editRange in
                let hasHighlight = textStorage.attribute(.backgroundColor, at: editRange.location, effectiveRange: nil) != nil

                if hasHighlight {
                    textStorage.removeAttribute(.backgroundColor, range: editRange)
                } else {
                    textStorage.addAttribute(.backgroundColor, value: highlightColor, range: editRange)
                }

                return true
            }
        } else {
            if textView.typingAttributes[.backgroundColor] != nil {
                textView.typingAttributes.removeValue(forKey: .backgroundColor)
            } else {
                textView.typingAttributes[.backgroundColor] = highlightColor
            }
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

    func togglePlainList() {
        guard let textView else { return }
        if textView.togglePlainList() {
            markDocumentEdited()
        }
        refreshFormattingState()
    }

    func toggleNumberedList() {
        guard let textView else { return }
        if textView.toggleNumberedList() {
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

        let lines = nsString.substring(with: paragraphRange)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return (false, false) }

        let isBulleted = lines.allSatisfy { $0.hasPrefix("- ") }
        let isNumbered = lines.allSatisfy {
            $0.range(of: #"^\d+\. "#, options: .regularExpression) != nil
        }

        return (isBulleted, isNumbered)
    }

    private func normalizedAlignment(_ alignment: NSTextAlignment) -> NSTextAlignment {
        alignment == .natural ? .left : alignment
    }

    private func displayFontFamilyName(for font: NSFont) -> String {
        let systemFontFamily = NSFont.systemFont(ofSize: font.pointSize).familyName

        if font.familyName == systemFontFamily || font.fontName.hasPrefix(".AppleSystem") {
            return "System"
        }

        return font.familyName ?? font.displayName ?? font.fontName
    }

    private func makeFont(name: String, size: Double, weight: NSFont.Weight) -> NSFont {
        if name == "System" {
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
        let font = attributes[.font] as? NSFont

        guard let familyName = font?.familyName, !familyName.isEmpty else {
            return "System"
        }

        return familyName == NSFont.systemFont(ofSize: font?.pointSize ?? 11).familyName
            ? "System"
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
