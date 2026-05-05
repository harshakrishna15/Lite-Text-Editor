import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var editor: EditorController
    @State private var isZoomMenuHovered = false
    @State private var isZoomPopoverPresented = false

    var body: some View {
        let activeStructureText = editor.activeStructureText

        ChromeGlassContainer(spacing: 8) {
            HStack(spacing: 12) {
                documentStatisticsText

                if !activeStructureText.isEmpty {
                    StatusBarDivider()

                    Text(activeStructureText)
                        .font(ChromeStyle.smallTextFont)
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 80, idealWidth: 180, maxWidth: 280, alignment: .leading)
                        .layoutPriority(1)
                }

                Spacer()

                predictionStatusText

                zoomControls
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 28)
        .background(ChromeBarBackground(separatorEdge: .top))
    }

    @ViewBuilder
    private var predictionStatusText: some View {
        if let statusText = editor.predictionState.statusText {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(predictionTint)

                Text(statusText)
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(predictionTint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 130, alignment: .trailing)
            .help(statusText)

            StatusBarDivider()
        }
    }

    private var documentStatisticsText: some View {
        HStack(spacing: 12) {
            Text("Pages: \(DocumentTextStatistics.formatted(editor.documentStatistics.pages))")
                .frame(minWidth: 58, alignment: .leading)

            Text("Words: \(DocumentTextStatistics.formatted(editor.documentStatistics.words))")
                .frame(minWidth: 74, alignment: .leading)
        }
        .font(ChromeStyle.smallTextFont)
        .monospacedDigit()
        .foregroundStyle(ChromeStyle.glassControlTextColor)
        .lineLimit(1)
        .fixedSize()
        .help("Document Statistics")
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
                .frame(height: ChromeStyle.statusBarZoomDropdownHeight)
                .chromeGlassControlBackground(
                    isActive: isZoomMenuHovered || isZoomPopoverPresented,
                    isSelected: isZoomPopoverPresented,
                    fallbackColor: isZoomMenuHovered || isZoomPopoverPresented ? ChromeStyle.toolbarHoverFill : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isZoomMenuHovered ? ChromeStyle.toolbarHoverOverlay : Color.clear)
                        .allowsHitTesting(false)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            isZoomMenuHovered || isZoomPopoverPresented ? ChromeStyle.toolbarHoverBorder : Color.clear,
                            lineWidth: isZoomMenuHovered || isZoomPopoverPresented ? 1 : 0
                        )
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isZoomMenuHovered = $0 }
            .accessibilityLabel("Zoom Size")
            .popover(isPresented: $isZoomPopoverPresented, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    ToolbarPopoverActionRow(
                        title: DocumentZoomPreset.fitPage.title,
                        symbol: "arrow.up.left.and.down.right.magnifyingglass",
                        isSelected: editor.selectedZoomPreset == .fitPage
                    ) {
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

    private var predictionTint: Color {
        switch editor.predictionState {
        case .predicting:
            return Color.accentColor
        default:
            return ChromeStyle.secondaryTextColor
        }
    }
}
