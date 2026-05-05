import SwiftUI

private struct ChromeGlassLiveResizeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isChromeGlassLiveResizing: Bool {
        get { self[ChromeGlassLiveResizeKey.self] }
        set { self[ChromeGlassLiveResizeKey.self] = newValue }
    }
}

enum ChromeRenderingPolicy {
    static let usesNativeLiquidGlass = false
    static let usesBackdropBlur = false
    static let usesSystemMaterialBackgrounds = false
    static let rimOverlayCount = 1
    static let usesMaskedLowerEdge = false
    static let floatingPanelShadowOpacity = 0.08
    static let floatingPanelShadowRadius: CGFloat = 4
    static let floatingPanelShadowYOffset: CGFloat = 2
    static let liveResizeFloatingPanelShadowOpacity = 0.0
    static let liveResizeFloatingPanelShadowRadius: CGFloat = 0

    static func usesNativeGlass(isLiveResizing: Bool) -> Bool {
        usesNativeLiquidGlass && !isLiveResizing
    }
}

enum ChromeGlassSurface {
    case toolbar
    case statusBar
    case panel
    case titlebarControl
    case control
    case selectedControl
    case pressedControl
}

private struct ChromeGlassBackgroundModifier<S: InsettableShape>: ViewModifier {
    let surface: ChromeGlassSurface
    let shape: S

    func body(content: Content) -> some View {
        content
            .background(shape.fill(surface.surfaceFill))
            .chromeGlassRim(surface: surface, shape: shape)
    }
}

private struct ChromeGlassControlBackgroundModifier<S: InsettableShape>: ViewModifier {
    let isActive: Bool
    let isSelected: Bool
    let isPressed: Bool
    let fallbackColor: Color
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            fallbackBody(content: content)
        } else {
            content.background(shape.fill(Color.clear))
        }
    }

    private var surface: ChromeGlassSurface {
        if isPressed {
            return .pressedControl
        }

        return isSelected ? .selectedControl : .control
    }

    private func fallbackBody(content: Content) -> some View {
        content
            .background(shape.fill(fallbackColor))
            .background(shape.fill(surface.surfaceFill))
            .chromeGlassRim(surface: surface, shape: shape)
    }
}

private struct ChromeGlassRimModifier<S: InsettableShape>: ViewModifier {
    let surface: ChromeGlassSurface
    let shape: S

    func body(content: Content) -> some View {
        content
            .overlay(
                shape
                    .strokeBorder(surface.rimColor, lineWidth: surface.rimLineWidth)
                    .allowsHitTesting(false)
            )
    }
}

private struct ChromeFloatingPanelShadowModifier: ViewModifier {
    @Environment(\.isChromeGlassLiveResizing) private var isLiveResizing

    @ViewBuilder
    func body(content: Content) -> some View {
        let shadowOpacity = isLiveResizing
            ? ChromeRenderingPolicy.liveResizeFloatingPanelShadowOpacity
            : ChromeRenderingPolicy.floatingPanelShadowOpacity
        let shadowRadius = isLiveResizing
            ? ChromeRenderingPolicy.liveResizeFloatingPanelShadowRadius
            : ChromeRenderingPolicy.floatingPanelShadowRadius
        let shadowYOffset = isLiveResizing ? 0 : ChromeRenderingPolicy.floatingPanelShadowYOffset

        if shadowOpacity <= 0 || shadowRadius <= 0 {
            content
        } else {
            content.shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowYOffset
            )
        }
    }
}

struct ChromeGlassContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}

struct ChromeBarBackground: View {
    enum SeparatorEdge {
        case top
        case bottom

        var alignment: Alignment {
            switch self {
            case .top:
                return .top
            case .bottom:
                return .bottom
            }
        }
    }

    var separatorEdge: SeparatorEdge

    var body: some View {
        Rectangle()
            .fill(ChromeStyle.chromeBarBackground)
            .overlay(alignment: separatorEdge.alignment) {
                Rectangle()
                    .fill(ChromeStyle.chromeBarBorder)
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func chromeGlassBackground<S: InsettableShape>(
        _ surface: ChromeGlassSurface = .panel,
        in shape: S
    ) -> some View {
        modifier(ChromeGlassBackgroundModifier(surface: surface, shape: shape))
    }

    func chromeGlassBar(_ surface: ChromeGlassSurface = .toolbar) -> some View {
        modifier(ChromeGlassBackgroundModifier(surface: surface, shape: Rectangle()))
    }

    func chromeGlassControlBackground<S: InsettableShape>(
        isActive: Bool,
        isSelected: Bool = false,
        isPressed: Bool = false,
        fallbackColor: Color,
        in shape: S
    ) -> some View {
        modifier(
            ChromeGlassControlBackgroundModifier(
                isActive: isActive,
                isSelected: isSelected,
                isPressed: isPressed,
                fallbackColor: fallbackColor,
                shape: shape
            )
        )
    }

    func chromeFloatingPanelShadow() -> some View {
        modifier(ChromeFloatingPanelShadowModifier())
    }

    fileprivate func chromeGlassRim<S: InsettableShape>(
        surface: ChromeGlassSurface,
        shape: S
    ) -> some View {
        modifier(ChromeGlassRimModifier(surface: surface, shape: shape))
    }
}

private extension ChromeGlassSurface {
    var rimLineWidth: CGFloat {
        switch self {
        case .toolbar, .statusBar:
            return 0.8
        case .panel:
            return 1.15
        case .titlebarControl, .control, .selectedControl, .pressedControl:
            return 1
        }
    }

    var surfaceFill: Color {
        switch self {
        case .toolbar, .statusBar:
            return ChromeStyle.chromeBarBackground
        case .panel:
            return ChromeStyle.chromePanelBackground
        case .titlebarControl, .control:
            return ChromeStyle.chromeControlBackground
        case .selectedControl:
            return ChromeStyle.chromeSelectedControlBackground
        case .pressedControl:
            return ChromeStyle.chromePressedControlBackground
        }
    }

    var rimColor: Color {
        switch self {
        case .toolbar, .statusBar:
            return ChromeStyle.chromeBarBorder
        case .panel:
            return ChromeStyle.chromePanelBorder
        case .titlebarControl, .control, .selectedControl, .pressedControl:
            return ChromeStyle.chromeControlBorder
        }
    }
}
