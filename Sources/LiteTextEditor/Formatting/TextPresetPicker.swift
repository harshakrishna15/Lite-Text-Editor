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
        button.previewFontName = fontName
        updateItems(for: button)
        select(selection, in: button)
        return button
    }

    func updateNSView(_ button: ToolbarPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.isBordered = false
        button.focusRingType = .none

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
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            guard oldValue != isHovered else { return }
            needsDisplay = true
        }
    }

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: ChromeStyle.toolbarControlHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        super.mouseExited(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        needsDisplay = true
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        needsDisplay = true
        return didResignFirstResponder
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawInteractionRing()
    }

    private func drawInteractionRing() {
        guard isHovered || isHighlighted || window?.firstResponder === self else { return }

        let isFocused = isHighlighted || window?.firstResponder === self
        let strokeColor = isFocused
            ? NSColor.controlAccentColor.withAlphaComponent(0.7)
            : NSColor.separatorColor.withAlphaComponent(0.72)
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 6,
            yRadius: 6
        )
        strokeColor.setStroke()
        path.lineWidth = isFocused ? 1.25 : 1
        path.stroke()
    }
}
