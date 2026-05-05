import AppKit
import SwiftUI

struct TextPresetPicker: NSViewRepresentable {
    @Binding var selection: TextPreset
    let fontName: String
    let onChange: (TextPreset) -> Void
    private let previewResolver = TextPresetPreviewResolver()

    func makeNSView(context: Context) -> ToolbarPopUpButton {
        let button = ToolbarPopUpButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectPreset(_:))
        button.controlSize = .regular
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        button.autoenablesItems = false
        button.focusRingType = .none
        button.cell?.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        button.previewFontName = fontName
        updateItems(for: button)
        select(selection, in: button)
        return button
    }

    func updateNSView(_ button: ToolbarPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.isBordered = false
        button.focusRingType = .none
        button.cell?.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow

        if button.itemValues != TextPreset.allCases.map(\.rawValue)
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

        TextPreset.allCases.forEach { preset in
            button.addItem(withTitle: preset.title)
            button.lastItem?.representedObject = preset.rawValue
            button.lastItem?.attributedTitle = previewResolver.menuTitle(for: preset, fontName: fontName)
        }

        button.itemValues = TextPreset.allCases.map(\.rawValue)
    }

    private func select(_ preset: TextPreset, in button: ToolbarPopUpButton) {
        guard let index = TextPreset.allCases.firstIndex(of: preset) else { return }
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

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ChromeStyle.toolbarControlHeight)
    }
}
