import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var editor: EditorController
    @Binding var selectedCountMetric: DocumentCountMetric
    @State private var isCountMenuHovered = false
    @State private var isCountPopoverPresented = false
    @State private var isZoomMenuHovered = false
    @State private var isZoomPopoverPresented = false

    var body: some View {
        ChromeGlassContainer(spacing: 8) {
            HStack(spacing: 12) {
                documentCountMenu

                if !editor.activeStructureText.isEmpty {
                    StatusBarDivider()

                    Text(editor.activeStructureText)
                        .font(ChromeStyle.smallTextFont)
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 140, alignment: .leading)
                        .layoutPriority(0)
                }

                Spacer()

                autosaveStatusText

                zoomControls
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 28)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var autosaveStatusText: some View {
        if let statusText = visibleAutosaveStatusText {
            Text(statusText)
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(autosaveTint)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 110, alignment: .trailing)
                .help(statusText)

            StatusBarDivider()
        }
    }

    private var documentCountMenu: some View {
        Button {
            isCountPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(selectedCountMetric.statusText(for: editor.documentStatistics))
                    .font(ChromeStyle.smallTextFont)
                    .monospacedDigit()
                    .foregroundStyle(ChromeStyle.glassControlTextColor)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ChromeStyle.glassSecondaryTextColor)
            }
            .padding(.horizontal, 6)
            .frame(height: 22)
            .chromeGlassControlBackground(
                isActive: true,
                fallbackColor: isCountMenuHovered ? ChromeStyle.toolbarHoverFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCountMenuHovered ? ChromeStyle.toolbarHoverOverlay : Color.clear)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isCountMenuHovered || isCountPopoverPresented ? ChromeStyle.toolbarHoverBorder : Color.clear,
                        lineWidth: isCountMenuHovered || isCountPopoverPresented ? 1 : 0
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isCountMenuHovered = $0 }
        .popover(isPresented: $isCountPopoverPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(DocumentCountMetric.allCases) { metric in
                    ToolbarPopoverActionRow(
                        title: metric.menuText(for: editor.documentStatistics),
                        symbol: "text.word.spacing",
                        isSelected: selectedCountMetric == metric
                    ) {
                        selectedCountMetric = metric
                        isCountPopoverPresented = false
                    }
                }
            }
            .padding(12)
            .frame(width: 238)
        }
        .fixedSize()
        .help("Document Counts")
        .animation(.easeOut(duration: 0.12), value: isCountMenuHovered)
        .animation(.easeOut(duration: 0.12), value: isCountPopoverPresented)
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button {
                isZoomPopoverPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(editor.zoomDisplayText)
                        .font(ChromeStyle.smallTextFont)
                        .monospacedDigit()
                        .foregroundStyle(ChromeStyle.glassControlTextColor)
                        .frame(width: 42, alignment: .trailing)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ChromeStyle.glassSecondaryTextColor)
                }
                .padding(.horizontal, 5)
                .frame(height: 20)
                .chromeGlassControlBackground(
                    isActive: true,
                    fallbackColor: isZoomMenuHovered ? ChromeStyle.toolbarHoverFill : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isZoomMenuHovered ? ChromeStyle.toolbarHoverOverlay : Color.clear)
                        .allowsHitTesting(false)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            isZoomMenuHovered || isZoomPopoverPresented ? ChromeStyle.toolbarHoverBorder : Color.clear,
                            lineWidth: isZoomMenuHovered || isZoomPopoverPresented ? 1 : 0
                        )
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isZoomMenuHovered = $0 }
            .popover(isPresented: $isZoomPopoverPresented, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    ToolbarPopoverActionRow(title: DocumentZoomPreset.fitPage.title, symbol: "arrow.up.left.and.down.right.magnifyingglass") {
                        editor.fitPageToScreen()
                        isZoomPopoverPresented = false
                    }

                    Divider()

                    ForEach(DocumentZoomPreset.fixedPresets) { preset in
                        ToolbarPopoverActionRow(
                            title: preset.title,
                            symbol: "magnifyingglass",
                            isSelected: editor.selectedZoomPreset == preset
                        ) {
                            editor.setZoomPreset(preset)
                            isZoomPopoverPresented = false
                        }
                    }
                }
                .padding(12)
                .frame(width: 156)
            }
            .fixedSize()
            .help("Zoom Size")
            .animation(.easeOut(duration: 0.12), value: isZoomMenuHovered)
            .animation(.easeOut(duration: 0.12), value: isZoomPopoverPresented)

            StatusBarIconButton(symbol: "minus", help: "Zoom Out") {
                editor.zoomOut()
            }

            zoomSlider

            StatusBarIconButton(symbol: "plus", help: "Zoom In") {
                editor.zoomIn()
            }
        }
        .frame(height: 22)
        .layoutPriority(2)
    }

    private var zoomSlider: some View {
        Slider(
            value: Binding(
                get: { editor.zoomMagnification },
                set: { editor.setZoomMagnification($0) }
            ),
            in: editor.minimumZoomMagnification...editor.maximumZoomMagnification
        )
        .frame(width: 120, height: 18)
        .controlSize(.small)
        .tint(Color.accentColor)
        .help("Zoom Slider")
    }

    private var visibleAutosaveStatusText: String? {
        switch editor.autosaveStatus {
        case .saving:
            return "Saving..."
        case .failed:
            return "Autosave failed"
        default:
            return nil
        }
    }

    private var autosaveTint: Color {
        switch editor.autosaveStatus {
        case .failed:
            return Color.red
        default:
            return ChromeStyle.secondaryTextColor
        }
    }
}
