import AppKit
import SwiftUI

struct EditableComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    let visibleItemCount: Int
    var autofillsCompletion = false
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> EditableComboBoxView {
        let comboBox = EditableComboBoxView()
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.commitSelection(_:))
        comboBox.isEditable = true
        comboBox.completes = autofillsCompletion
        comboBox.usesDataSource = false
        comboBox.numberOfVisibleItems = visibleItemCount
        comboBox.controlSize = .regular
        comboBox.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        comboBox.bezelStyle = .roundedBezel
        comboBox.isBordered = true
        comboBox.drawsBackground = true
        comboBox.backgroundColor = .controlBackgroundColor
        comboBox.cell?.alignment = .left
        comboBox.cell?.lineBreakMode = .byTruncatingTail
        comboBox.cell?.usesSingleLineMode = true
        comboBox.focusRingType = .default
        comboBox.stringValue = text
        updateItems(for: comboBox)
        return comboBox
    }

    func updateNSView(_ comboBox: EditableComboBoxView, context: Context) {
        context.coordinator.parent = self
        comboBox.numberOfVisibleItems = visibleItemCount
        comboBox.completes = autofillsCompletion

        if comboBox.itemValues != items {
            updateItems(for: comboBox)
        }

        if !context.coordinator.isPopupOpen,
           comboBox.currentEditor() == nil,
           comboBox.stringValue != text {
            comboBox.stringValue = text
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

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: EditableComboBox
        var isPopupOpen = false
        private var isApplyingCompletion = false

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

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox.stringValue)
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
            }

            let typedText = editor.string

            guard !comboBox.shouldSkipCompletionForCurrentEdit else {
                parent.text = typedText
                return true
            }

            guard !typedText.isEmpty else {
                parent.text = typedText
                return true
            }

            guard let completion = parent.items.first(where: { item in
                item.range(
                    of: typedText,
                    options: [.caseInsensitive, .diacriticInsensitive, .anchored]
                ) != nil
            }) else {
                parent.text = typedText
                return true
            }

            let typedLength = (typedText as NSString).length
            let completionLength = (completion as NSString).length

            guard completionLength > typedLength else {
                parent.text = typedText
                return true
            }

            isApplyingCompletion = true
            comboBox.stringValue = completion
            editor.string = completion
            editor.selectedRange = NSRange(
                location: typedLength,
                length: completionLength - typedLength
            )
            isApplyingCompletion = false
            parent.text = completion
            return true
        }
    }
}

final class EditableComboBoxView: NSComboBox {
    var itemValues: [String] = []
    var shouldSkipCompletionForCurrentEdit = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ChromeStyle.toolbarControlHeight)
    }

    override func keyDown(with event: NSEvent) {
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
            menuItem.state = item == stringValue ? .on : .off
            menu.addItem(menuItem)
        }

        let popupOrigin = NSPoint(x: bounds.minX, y: bounds.maxY + 2)
        menu.popUp(positioning: nil, at: popupOrigin, in: self)
    }

    @objc private func selectHighlightedMenuItem(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        stringValue = value
        _ = sendAction(action, to: target)
    }
}
