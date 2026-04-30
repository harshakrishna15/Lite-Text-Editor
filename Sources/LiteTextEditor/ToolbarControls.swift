import AppKit
import SwiftUI

struct TextColorPaletteButton: View {
    @Binding var selectedColor: Color
    @Binding var customColors: [PaletteColor]

    let onApplyColor: (Color) -> Void

    @State private var isPalettePresented = false
    @State private var isHovered = false

    var body: some View {
        Button {
            isPalettePresented.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "textformat")
                    .font(ChromeStyle.controlSymbolFont)
                    .foregroundStyle(ChromeStyle.controlTextColor)
                    .frame(width: 18, height: 14)

                RoundedRectangle(cornerRadius: 1)
                    .fill(selectedColor)
                    .frame(width: 16, height: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: isPalettePresented, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel("Text Color")
        .popover(isPresented: $isPalettePresented, arrowEdge: .bottom) {
            TextColorPaletteView(
                selectedColor: $selectedColor,
                customColors: $customColors,
                onApplyColor: onApplyColor
            )
            .padding(12)
            .frame(width: 258)
        }
        .help("Text Color")
    }
}

private struct TextColorPaletteView: View {
    @Binding var selectedColor: Color
    @Binding var customColors: [PaletteColor]

    let onApplyColor: (Color) -> Void

    private let columns = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preset Colors")
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(TextColorPreset.all) { preset in
                    ColorSwatchButton(
                        title: preset.name,
                        paletteColor: preset.color,
                        isSelected: PaletteColor(selectedColor) == preset.color
                    ) {
                        applyColor(preset.color.color)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("Custom Palette")
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)

                Spacer()

                Button("Save Color") {
                    saveCurrentColor()
                }
                .font(ChromeStyle.smallTextFont)
            }

            if customColors.isEmpty {
                Text("No saved colors")
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(customColors) { customColor in
                        ColorSwatchButton(
                            title: "Custom Color",
                            paletteColor: customColor,
                            isSelected: PaletteColor(selectedColor) == customColor
                        ) {
                            applyColor(customColor.color)
                        }
                    }
                }
            }

            ColorPicker(
                "Current Color",
                selection: Binding(
                    get: { selectedColor },
                    set: { applyColor($0) }
                ),
                supportsOpacity: false
            )
            .font(ChromeStyle.controlTextFont)

            if !customColors.isEmpty {
                Button("Clear Custom Colors") {
                    customColors = []
                    TextColorPaletteStore.save(customColors)
                }
                .font(ChromeStyle.smallTextFont)
            }
        }
    }

    private func applyColor(_ color: Color) {
        selectedColor = color
        onApplyColor(color)
    }

    private func saveCurrentColor() {
        let paletteColor = PaletteColor(selectedColor)
        var savedColors = customColors.filter { $0 != paletteColor }
        savedColors.append(paletteColor)
        customColors = Array(savedColors.suffix(TextColorPaletteStore.maximumCustomColors))
        TextColorPaletteStore.save(customColors)
    }
}

private struct ColorSwatchButton: View {
    let title: String
    let paletteColor: PaletteColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(paletteColor.color)
                .frame(width: 24, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.18), lineWidth: isSelected ? 2 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

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

struct TextPresetPicker: NSViewRepresentable {
    @Binding var selection: TextPreset
    let onChange: (TextPreset) -> Void

    func makeNSView(context: Context) -> ToolbarPopUpButton {
        let button = ToolbarPopUpButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectPreset(_:))
        button.controlSize = .regular
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        button.autoenablesItems = false
        updateItems(for: button)
        select(selection, in: button)
        return button
    }

    func updateNSView(_ button: ToolbarPopUpButton, context: Context) {
        context.coordinator.parent = self

        if button.itemValues != TextPreset.allCases.map(\.rawValue) {
            updateItems(for: button)
        }

        if button.selectedItem?.representedObject as? String != selection.rawValue {
            select(selection, in: button)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func updateItems(for button: ToolbarPopUpButton) {
        button.removeAllItems()

        TextPreset.allCases.forEach { preset in
            button.addItem(withTitle: preset.title)
            button.lastItem?.representedObject = preset.rawValue
        }

        button.itemValues = TextPreset.allCases.map(\.rawValue)
    }

    private func select(_ preset: TextPreset, in button: ToolbarPopUpButton) {
        guard let index = TextPreset.allCases.firstIndex(of: preset) else { return }
        button.selectItem(at: index)
    }

    final class Coordinator: NSObject {
        var parent: TextPresetPicker

        init(parent: TextPresetPicker) {
            self.parent = parent
        }

        @objc func selectPreset(_ sender: NSPopUpButton) {
            guard let rawValue = sender.selectedItem?.representedObject as? String,
                  let preset = TextPreset(rawValue: rawValue) else {
                return
            }

            parent.selection = preset
            parent.onChange(preset)
        }
    }
}

final class ToolbarPopUpButton: NSPopUpButton {
    var itemValues: [String] = []

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ChromeStyle.toolbarControlHeight)
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: ChromeStyle.toolbarControlHeight)
            .padding(.horizontal, 2)
    }
}

struct ToolbarSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarItemSpacing) {
            content()
        }
        .padding(.horizontal, 3)
    }
}

struct StatusBarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 16)
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return ChromeStyle.toolbarPressedFill
        }

        if isSelected {
            return ChromeStyle.toolbarSelectedFill
        }

        if isHovered {
            return ChromeStyle.toolbarHoverFill
        }

        return .clear
    }
}

struct RibbonIconButton: View {
    let symbol: String
    let help: String
    var isSelected = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(ChromeStyle.controlSymbolFont)
                .foregroundStyle(isSelected ? Color.accentColor : ChromeStyle.controlTextColor)
                .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: isSelected, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}

struct StatusBarIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(ChromeStyle.controlSymbolFont)
                .foregroundStyle(ChromeStyle.controlTextColor)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: false, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}
