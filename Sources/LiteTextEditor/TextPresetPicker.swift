import AppKit
import SwiftUI

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
