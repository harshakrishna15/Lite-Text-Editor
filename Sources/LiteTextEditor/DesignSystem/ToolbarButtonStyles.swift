import SwiftUI

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
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(
                        borderColor(isPressed: configuration.isPressed),
                        lineWidth: borderWidth(isPressed: configuration.isPressed)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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

    private func borderColor(isPressed: Bool) -> Color {
        if isPressed || isSelected {
            return ChromeStyle.toolbarSelectedBorder
        }

        return isHovered ? ChromeStyle.toolbarHoverBorder : .clear
    }

    private func borderWidth(isPressed: Bool) -> CGFloat {
        isPressed || isSelected || isHovered ? 1 : 0
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

struct ToolbarMenuButton<Content: View>: View {
    let title: String
    let symbol: String
    let help: String
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(ChromeStyle.controlSymbolFont)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
            }
            .foregroundStyle(ChromeStyle.controlTextColor)
            .frame(width: ChromeStyle.toolbarIconWidth + 8, height: ChromeStyle.toolbarControlHeight)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? ChromeStyle.toolbarHoverFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(
                        isHovered ? ChromeStyle.toolbarHoverBorder : Color.clear,
                        lineWidth: isHovered ? 1 : 0
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}
