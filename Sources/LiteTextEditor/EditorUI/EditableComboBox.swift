import AppKit
import SwiftUI

struct EditableComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    let visibleItemCount: Int
    var autofillsCompletion = false
    var previewsFontFamilies = false
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> EditableComboBoxView {
        let comboBox = EditableComboBoxView()
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.commitSelection(_:))
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.usesDataSource = false
        comboBox.numberOfVisibleItems = visibleItemCount
        comboBox.controlSize = .regular
        comboBox.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        comboBox.bezelStyle = .roundedBezel
        comboBox.isBordered = true
        comboBox.drawsBackground = true
        comboBox.backgroundColor = .controlBackgroundColor
        comboBox.textColor = .controlTextColor
        comboBox.cell?.alignment = .left
        comboBox.cell?.lineBreakMode = .byTruncatingTail
        comboBox.cell?.usesSingleLineMode = true
        comboBox.focusRingType = .none
        comboBox.stringValue = text
        comboBox.previewsFontFamilies = previewsFontFamilies
        updateItems(for: comboBox)
        updateDisplayFont(for: comboBox)
        return comboBox
    }

    func updateNSView(_ comboBox: EditableComboBoxView, context: Context) {
        context.coordinator.parent = self
        comboBox.numberOfVisibleItems = visibleItemCount
        comboBox.completes = false
        comboBox.previewsFontFamilies = previewsFontFamilies
        comboBox.isBordered = true
        comboBox.drawsBackground = true
        comboBox.backgroundColor = .controlBackgroundColor
        comboBox.textColor = .controlTextColor
        comboBox.focusRingType = .none

        if comboBox.itemValues != items {
            updateItems(for: comboBox)
        }

        if !context.coordinator.isPopupOpen,
           comboBox.currentEditor() == nil,
           comboBox.stringValue != text {
            comboBox.stringValue = text
        }

        if comboBox.currentEditor() == nil {
            updateDisplayFont(for: comboBox)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func updateItems(for comboBox: EditableComboBoxView) {
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: items)
        comboBox.itemValues = items
    }

    private func updateDisplayFont(for comboBox: EditableComboBoxView) {
        comboBox.font = comboBox.displayFont(for: text)
        comboBox.textColor = .controlTextColor
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: EditableComboBox
        var isPopupOpen = false
        private var isApplyingCompletion = false
        private let completionResolver = ComboBoxCompletionResolver()

        init(parent: EditableComboBox) {
            self.parent = parent
        }

        @objc func commitSelection(_ sender: NSComboBox) {
            commit(sender.stringValue)
        }

        func comboBoxWillPopUp(_ notification: Notification) {
            isPopupOpen = true
        }

        func comboBoxWillDismiss(_ notification: Notification) {
            isPopupOpen = false
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox.stringValue)
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            if !isPopupOpen {
                commit(comboBox.stringValue)
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            guard !isPopupOpen else { return }
            guard !isApplyingCompletion else { return }

            if applyCompletionIfNeeded(to: comboBox) {
                return
            }

            parent.text = comboBox.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? EditableComboBoxView else { return }
            let editor = comboBox.currentEditor()
            comboBox.previousEditorText = editor?.string ?? comboBox.stringValue
            comboBox.previousSelectionRange = editor?.selectedRange ?? NSRange(
                location: (comboBox.previousEditorText as NSString).length,
                length: 0
            )
            comboBox.shouldSkipCompletionForCurrentEdit = false
            comboBox.setKeyboardFocused(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? EditableComboBoxView else { return }
            comboBox.setKeyboardFocused(false)
            commit(comboBox.stringValue)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard let comboBox = control as? EditableComboBoxView else { return false }
            comboBox.previousEditorText = textView.string
            comboBox.previousSelectionRange = textView.selectedRange()
            comboBox.shouldSkipCompletionForCurrentEdit = isDeletionCommand(commandSelector)
            return false
        }

        private func commit(_ value: String) {
            parent.text = value
            parent.onCommit(value)
        }

        private func applyCompletionIfNeeded(to comboBox: NSComboBox) -> Bool {
            guard parent.autofillsCompletion,
                  let comboBox = comboBox as? EditableComboBoxView,
                  let editor = comboBox.currentEditor() else {
                return false
            }

            defer {
                comboBox.shouldSkipCompletionForCurrentEdit = false
                comboBox.previousEditorText = editor.string
                comboBox.previousSelectionRange = editor.selectedRange
            }

            let typedText = editor.string
            let decision = completionResolver.decision(
                typedText: typedText,
                previousText: comboBox.previousEditorText,
                previousSelectionRange: comboBox.previousSelectionRange,
                shouldSkipCompletion: comboBox.shouldSkipCompletionForCurrentEdit,
                items: parent.items
            )

            guard decision.completed else {
                parent.text = decision.text
                return true
            }

            isApplyingCompletion = true
            comboBox.stringValue = decision.text
            editor.string = decision.text
            editor.selectedRange = decision.selectedRange
            isApplyingCompletion = false
            parent.text = decision.text
            return true
        }

        private func isDeletionCommand(_ commandSelector: Selector) -> Bool {
            let commandName = NSStringFromSelector(commandSelector)
            return [
                "deleteBackward:",
                "deleteForward:",
                "deleteWordBackward:",
                "deleteWordForward:",
                "deleteToBeginningOfLine:",
                "deleteToEndOfLine:",
                "deleteToBeginningOfParagraph:",
                "deleteToEndOfParagraph:"
            ].contains(commandName)
        }
    }
}

final class EditableComboBoxView: NSComboBox {
    var itemValues: [String] = []
    var previewsFontFamilies = false
    var shouldSkipCompletionForCurrentEdit = false
    var previousEditorText = ""
    var previousSelectionRange = NSRange(location: 0, length: 0)
    private let fontPreviewResolver = FontPreviewResolver()
    private var isKeyboardFocused = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ChromeStyle.toolbarControlHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isKeyboardFocused else { return }

        NSGraphicsContext.saveGraphicsState()
        let focusPath = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
            xRadius: 8,
            yRadius: 8
        )
        NSColor.controlAccentColor.withAlphaComponent(0.82).setStroke()
        focusPath.lineWidth = 2
        focusPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    func setKeyboardFocused(_ isFocused: Bool) {
        guard isKeyboardFocused != isFocused else { return }
        isKeyboardFocused = isFocused
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let editor = currentEditor()
        previousEditorText = editor?.string ?? stringValue
        previousSelectionRange = editor?.selectedRange ?? NSRange(
            location: (previousEditorText as NSString).length,
            length: 0
        )
        shouldSkipCompletionForCurrentEdit = event.keyCode == 51 || event.keyCode == 117
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if arrowButtonRect.contains(location) {
            showHighlightedMenu()
            return
        }

        super.mouseDown(with: event)
    }

    private var arrowButtonRect: NSRect {
        NSRect(
            x: max(bounds.maxX - 28, bounds.minX),
            y: bounds.minY,
            width: min(28, bounds.width),
            height: bounds.height
        )
    }

    private func showHighlightedMenu() {
        guard !itemValues.isEmpty else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false

        itemValues.forEach { item in
            let menuItem = NSMenuItem(title: item, action: #selector(selectHighlightedMenuItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            if previewsFontFamilies {
                menuItem.attributedTitle = fontPreviewResolver.attributedTitle(for: item)
            }
            menuItem.state = item == stringValue ? .on : .off
            menu.addItem(menuItem)
        }

        let popupOrigin = NSPoint(x: bounds.minX, y: bounds.maxY + 2)
        menu.popUp(positioning: nil, at: popupOrigin, in: self)
    }

    @objc private func selectHighlightedMenuItem(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        stringValue = value
        font = displayFont(for: value)
        _ = sendAction(action, to: target)
    }

    func displayFont(for value: String) -> NSFont {
        guard previewsFontFamilies else {
            return NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        }

        return fontPreviewResolver.font(for: value)
    }
}
