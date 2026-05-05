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
                    .foregroundStyle(isHovered ? ChromeStyle.controlTextColor : ChromeStyle.glassControlTextColor)
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
