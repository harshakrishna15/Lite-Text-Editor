import AppKit
import SwiftUI

struct TextPresetPicker: NSViewRepresentable {
    @Binding var selection: TextPreset
    let fontName: String
    let onChange: (TextPreset) -> Void
    private let previewResolver = TextPresetPreviewResolver()
    private let displayedPresets = TextPreset.allCases.filter { $0 != .script }

    func makeNSView(context: Context) -> ToolbarPopUpButton {
        let button = ToolbarPopUpButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectPreset(_:))
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        button.autoenablesItems = false
        button.cell?.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail
        button.previewFontName = fontName
        updateItems(for: button)
        select(selection, in: button)
        return button
    }

    func updateNSView(_ button: ToolbarPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.controlSize = .small
        button.isBordered = true
        button.cell?.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail

        if button.itemValues != displayedPresets.map(\.rawValue)
            || button.previewFontName != fontName {
            button.previewFontName = fontName
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

        displayedPresets.forEach { preset in
            button.addItem(withTitle: preset.title)
            button.lastItem?.representedObject = preset.rawValue
            button.lastItem?.attributedTitle = previewResolver.menuTitle(for: preset, fontName: fontName)
        }

        button.itemValues = displayedPresets.map(\.rawValue)
    }

    private func select(_ preset: TextPreset, in button: ToolbarPopUpButton) {
        guard let index = displayedPresets.firstIndex(of: preset) else { return }
        button.selectItem(at: index)
        button.selectedItem?.attributedTitle = previewResolver.buttonTitle(for: preset, fontName: fontName)
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
    var previewFontName = "System"

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }
}
