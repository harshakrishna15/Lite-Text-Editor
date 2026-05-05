import AppKit
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

enum ChromeGlassSurface {
    case toolbar
    case statusBar
    case panel
    case titlebarControl
    case control
    case selectedControl
    case pressedControl

    var fallbackMaterial: Material {
        switch self {
        case .toolbar, .statusBar:
            return .ultraThinMaterial
        case .panel:
            return .thinMaterial
        default:
            return .ultraThinMaterial
        }
    }
}

private struct ChromeGlassBackgroundModifier<S: Shape>: ViewModifier {
    @Environment(\.isChromeGlassLiveResizing) private var isLiveResizing

    let surface: ChromeGlassSurface
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !isChromeGlassLiveResizeActive {
            content
                .glassEffect(surface.nativeGlass, in: shape)
                .chromeGlassRim(surface: surface, shape: shape)
        } else {
            fallbackBody(content: content)
        }
        #else
        fallbackBody(content: content)
        #endif
    }

    private func fallbackBody(content: Content) -> some View {
        content
            .background(surface.fallbackMaterial, in: shape)
            .background(shape.fill(surface.surfaceTint))
            .chromeGlassRim(surface: surface, shape: shape)
    }

    private var isChromeGlassLiveResizeActive: Bool {
        isLiveResizing
    }
}

private struct ChromeGlassControlBackgroundModifier<S: Shape>: ViewModifier {
    let isActive: Bool
    let isSelected: Bool
    let isPressed: Bool
    let fallbackColor: Color
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(surface.nativeGlass, in: shape)
                    .chromeGlassRim(surface: surface, shape: shape)
            } else {
                fallbackBody(content: content)
            }
            #else
            fallbackBody(content: content)
            #endif
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
            .background(shape.fill(surface.surfaceTint))
            .chromeGlassRim(surface: surface, shape: shape)
    }
}

private struct ChromeGlassRimModifier<S: Shape>: ViewModifier {
    let surface: ChromeGlassSurface
    let shape: S

    func body(content: Content) -> some View {
        content
            .overlay(
                shape
                    .stroke(surface.outerRimColor, lineWidth: surface.rimLineWidth)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .stroke(surface.innerHighlightColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .stroke(surface.lowerEdgeColor, lineWidth: 0.75)
                    .offset(y: 1)
                    .mask(shape)
                    .allowsHitTesting(false)
            )
    }
}

struct ChromeGlassContainer<Content: View>: View {
    @Environment(\.isChromeGlassLiveResizing) private var isLiveResizing

    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !isChromeGlassLiveResizeActive {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
        #else
        content()
        #endif
    }

    private var isChromeGlassLiveResizeActive: Bool {
        isLiveResizing
    }
}

struct ChromeBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.state = .active
        view.isEmphasized = false
        view.appearance = ChromeStyle.appearance
    }
}

extension View {
    func chromeGlassBackground<S: Shape>(
        _ surface: ChromeGlassSurface = .panel,
        in shape: S
    ) -> some View {
        modifier(ChromeGlassBackgroundModifier(surface: surface, shape: shape))
    }

    func chromeGlassBar(_ surface: ChromeGlassSurface = .toolbar) -> some View {
        modifier(ChromeGlassBackgroundModifier(surface: surface, shape: Rectangle()))
    }

    func chromeGlassControlBackground<S: Shape>(
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

    fileprivate func chromeGlassRim<S: Shape>(
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

    var surfaceTint: Color {
        switch self {
        case .toolbar:
            return Color.white.opacity(0.12)
        case .statusBar:
            return Color.white.opacity(0.10)
        case .panel:
            return Color.white.opacity(0.18)
        case .titlebarControl, .control:
            return Color.white.opacity(0.16)
        case .selectedControl:
            return Color.accentColor.opacity(0.12)
        case .pressedControl:
            return Color.accentColor.opacity(0.16)
        }
    }

    var outerRimColor: Color {
        switch self {
        case .toolbar, .statusBar:
            return Color.white.opacity(0.36)
        case .panel:
            return Color.white.opacity(0.42)
        case .titlebarControl, .control, .selectedControl, .pressedControl:
            return Color.white.opacity(0.46)
        }
    }

    var innerHighlightColor: Color {
        switch self {
        case .toolbar, .statusBar:
            return Color.white.opacity(0.20)
        case .panel:
            return Color.white.opacity(0.26)
        case .titlebarControl, .control, .selectedControl, .pressedControl:
            return Color.white.opacity(0.30)
        }
    }

    var lowerEdgeColor: Color {
        switch self {
        case .toolbar, .statusBar:
            return Color.black.opacity(0.08)
        case .panel:
            return Color.black.opacity(0.10)
        case .titlebarControl, .control, .selectedControl, .pressedControl:
            return Color.black.opacity(0.08)
        }
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private extension ChromeGlassSurface {
    var nativeGlass: Glass {
        switch self {
        case .toolbar, .statusBar, .panel:
            return Glass.regular
        case .titlebarControl:
            return Glass.regular
                .interactive(true)
        case .control:
            return Glass.regular
                .interactive(true)
        case .selectedControl:
            return Glass.regular
                .tint(Color.accentColor.opacity(0.18))
                .interactive(true)
        case .pressedControl:
            return Glass.regular
                .tint(Color.accentColor.opacity(0.26))
                .interactive(true)
        }
    }
}
#endif
