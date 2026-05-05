import SwiftUI

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.22))
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
            .fill(Color.white.opacity(0.20))
            .frame(width: 1, height: 16)
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: ChromeStyle.toolbarControlCornerRadius, style: .continuous)
        let usesGlass = isSelected || isHovered || configuration.isPressed

        configuration.label
            .chromeGlassControlBackground(
                isActive: usesGlass,
                isSelected: isSelected,
                isPressed: configuration.isPressed,
                fallbackColor: backgroundColor(isPressed: configuration.isPressed),
                in: shape
            )
            .overlay(
                shape
                    .fill(hoverOverlayColor(isPressed: configuration.isPressed))
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .strokeBorder(
                        borderColor(isPressed: configuration.isPressed),
                        lineWidth: borderWidth(isPressed: configuration.isPressed)
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
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

    private func borderColor(isPressed: Bool) -> Color {
        if isPressed || isSelected {
            return ChromeStyle.toolbarSelectedBorder
        }

        return isHovered ? ChromeStyle.toolbarHoverBorder : .clear
    }

    private func borderWidth(isPressed: Bool) -> CGFloat {
        isPressed || isSelected || isHovered ? 1 : 0
    }

    private func hoverOverlayColor(isPressed: Bool) -> Color {
        guard isHovered && !isPressed else { return .clear }
        return isSelected ? Color.accentColor.opacity(0.055) : ChromeStyle.toolbarHoverOverlay
    }
}

struct RibbonIconButton: View {
    let symbol: String
    let help: String
    var isSelected = false
    var isToggle = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(ChromeStyle.controlSymbolFont)
                .foregroundStyle(iconColor)
                .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: isSelected, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
        .accessibilitySelectedState(isToggle ? isSelected : nil)
        .help(help)
    }

    private var iconColor: Color {
        if isSelected {
            return Color.accentColor
        }

        return isHovered ? ChromeStyle.controlTextColor : ChromeStyle.glassControlTextColor
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
                .foregroundStyle(isHovered ? ChromeStyle.controlTextColor : ChromeStyle.glassControlTextColor)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: false, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}

struct ToolbarPopoverButton<Content: View>: View {
    let title: String
    let symbol: String
    let help: String
    var width: CGFloat = 240
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content

    @State private var isHovered = false
    @State private var isPresented = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ChromeStyle.toolbarControlCornerRadius, style: .continuous)

        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(ChromeStyle.controlSymbolFont)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ChromeStyle.glassSecondaryTextColor)
            }
            .foregroundStyle(isHovered ? ChromeStyle.controlTextColor : ChromeStyle.glassControlTextColor)
            .frame(width: ChromeStyle.toolbarIconWidth + 8, height: ChromeStyle.toolbarControlHeight)
            .chromeGlassControlBackground(
                isActive: isPresented || isHovered,
                isSelected: isPresented,
                fallbackColor: isPresented || isHovered ? ChromeStyle.toolbarHoverFill : Color.clear,
                in: shape
            )
            .overlay(
                shape
                    .fill(isHovered ? ChromeStyle.toolbarHoverOverlay : Color.clear)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .strokeBorder(
                        isPresented || isHovered ? ChromeStyle.toolbarSelectedBorder : Color.clear,
                        lineWidth: isPresented || isHovered ? 1 : 0
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            content { isPresented = false }
                .padding(12)
                .frame(width: width)
        }
        .help(help)
        .accessibilityLabel(title)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isPresented)
    }
}

struct ToolbarPopoverSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)

            content()
        }
    }
}

struct ToolbarPopoverActionRow: View {
    let title: String
    let symbol: String
    var isSelected = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(ChromeStyle.controlSymbolFont)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(ChromeStyle.controlTextFont)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(ChromeStyle.controlTextColor)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: ChromeStyle.toolbarPopoverRowCornerRadius, style: .continuous)
                    .fill(isHovered || isSelected ? Color.accentColor.opacity(isSelected ? 0.16 : 0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilitySelectedState(isSelected ? true : nil)
    }
}

extension View {
    @ViewBuilder
    func accessibilitySelectedState(_ isSelected: Bool?) -> some View {
        if let isSelected {
            if isSelected {
                self
                    .accessibilityValue("On")
                    .accessibilityAddTraits(.isSelected)
            } else {
                self.accessibilityValue("Off")
            }
        } else {
            self
        }
    }
}
