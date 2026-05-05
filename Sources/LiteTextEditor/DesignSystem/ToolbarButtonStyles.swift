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
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let hoverLift = hoverLift(isPressed: configuration.isPressed)
        let hoverScale = hoverScale(isPressed: configuration.isPressed)
        let hoverShadowRadius = hoverShadowRadius(isPressed: configuration.isPressed)

        configuration.label
            .chromeGlassControlBackground(
                isActive: true,
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
                    .stroke(
                        borderColor(isPressed: configuration.isPressed),
                        lineWidth: borderWidth(isPressed: configuration.isPressed)
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
            .shadow(
                color: shadowColor(isPressed: configuration.isPressed),
                radius: hoverShadowRadius,
                x: 0,
                y: hoverLift > 0 ? 1 : 0
            )
            .offset(y: -hoverLift)
            .scaleEffect(configuration.isPressed ? 0.95 : hoverScale)
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

    private func shadowColor(isPressed: Bool) -> Color {
        guard isHovered && !isPressed else { return .clear }
        return isSelected ? ChromeStyle.toolbarHoverShadow.opacity(0.55) : ChromeStyle.toolbarHoverShadow
    }

    private func hoverLift(isPressed: Bool) -> CGFloat {
        guard isHovered && !isPressed else { return 0 }
        return isSelected ? 0.5 : 1
    }

    private func hoverScale(isPressed: Bool) -> CGFloat {
        guard isHovered && !isPressed else { return 1 }
        return isSelected ? 1.015 : 1.04
    }

    private func hoverShadowRadius(isPressed: Bool) -> CGFloat {
        guard isHovered && !isPressed else { return 0 }
        return isSelected ? 2 : 4
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
                .foregroundStyle(iconColor)
                .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: isSelected, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
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
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconButtonStyle(isSelected: false, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(help)
        .help(help)
    }
}

struct ToolbarMenuButton<Content: View>: View {
    let title: String
    let symbol: String
    let help: String
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        Menu {
            content()
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
                isActive: true,
                fallbackColor: isHovered ? ChromeStyle.toolbarHoverFill : Color.clear,
                in: shape
            )
            .overlay(
                shape
                    .fill(isHovered ? ChromeStyle.toolbarHoverOverlay : Color.clear)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .stroke(
                        isHovered ? ChromeStyle.toolbarHoverBorder : Color.clear,
                        lineWidth: isHovered ? 1 : 0
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
            .shadow(
                color: isHovered ? ChromeStyle.toolbarHoverShadow : .clear,
                radius: isHovered ? 4 : 0,
                x: 0,
                y: isHovered ? 1 : 0
            )
            .offset(y: isHovered ? -1 : 0)
            .scaleEffect(isHovered ? 1.03 : 1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
