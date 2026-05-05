import SwiftUI

struct TextColorPaletteButton: View {
    @Binding var selectedColor: Color
    @Binding var customColors: [PaletteColor]

    let onApplyColor: (Color) -> Void

    @State private var isPalettePresented = false
    @State private var isHovered = false

    var body: some View {
        ToolbarPaletteButton(
            symbol: "textformat",
            accessibilityLabel: "Text Color",
            help: "Text Color",
            indicatorColor: selectedColor,
            isSelected: isPalettePresented,
            isPalettePresented: $isPalettePresented,
            isHovered: $isHovered
        ) {
            TextColorPaletteView(
                selectedColor: $selectedColor,
                customColors: $customColors,
                onApplyColor: onApplyColor
            )
            .padding(12)
            .frame(width: 258)
        }
    }
}

struct HighlightColorPaletteButton: View {
    let hasHighlight: Bool
    let onApplyHighlight: (HighlightColorOption) -> Void

    @State private var isPalettePresented = false
    @State private var isHovered = false

    var body: some View {
        ToolbarPaletteButton(
            symbol: "paintbrush.pointed",
            accessibilityLabel: "Highlight Color",
            help: "Highlight Color",
            indicatorColor: hasHighlight ? Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.65)) : .clear,
            indicatorStrokeColor: hasHighlight ? Color.black.opacity(0.20) : ChromeStyle.glassSecondaryTextColor.opacity(0.45),
            isSelected: isPalettePresented || hasHighlight,
            selectedIconColor: hasHighlight || isPalettePresented ? .accentColor : nil,
            isPalettePresented: $isPalettePresented,
            isHovered: $isHovered
        ) {
            HighlightColorPaletteView { option in
                onApplyHighlight(option)
                isPalettePresented = false
            }
            .padding(12)
            .frame(width: 190)
        }
    }
}

private struct ToolbarPaletteButton<Content: View>: View {
    let symbol: String
    let accessibilityLabel: String
    let help: String
    let indicatorColor: Color
    var indicatorStrokeColor = Color.black.opacity(0.20)
    let isSelected: Bool
    var selectedIconColor: Color?
    @Binding var isPalettePresented: Bool
    @Binding var isHovered: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            isPalettePresented.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(ChromeStyle.controlSymbolFont)
                    .foregroundStyle(iconColor)
                    .frame(width: 18, height: 14)

                RoundedRectangle(cornerRadius: 1)
                    .fill(indicatorColor)
                    .frame(width: 16, height: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(indicatorStrokeColor, lineWidth: 0.5)
                    )
            }
            .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: isSelected, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isPalettePresented, arrowEdge: .bottom, content: content)
        .help(help)
    }

    private var iconColor: Color {
        selectedIconColor ?? (isHovered ? ChromeStyle.controlTextColor : ChromeStyle.glassControlTextColor)
    }
}

private struct HighlightColorPaletteView: View {
    let onApplyHighlight: (HighlightColorOption) -> Void

    private let columns = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlight Color")
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(HighlightColorOption.allCases.filter { $0 != .clear }, id: \.rawValue) { option in
                    PaletteSwatchButton(
                        title: option.title,
                        color: option.color.map { Color(nsColor: $0) } ?? Color.clear
                    ) {
                        onApplyHighlight(option)
                    }
                }
            }

            Divider()

            ToolbarPopoverActionRow(title: HighlightColorOption.clear.title, symbol: "xmark.circle") {
                onApplyHighlight(.clear)
            }
        }
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
                    PaletteSwatchButton(
                        title: preset.name,
                        color: preset.color.color,
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
                        PaletteSwatchButton(
                            title: "Custom Color",
                            color: customColor.color,
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

private struct PaletteSwatchButton: View {
    let title: String
    let color: Color
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
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
