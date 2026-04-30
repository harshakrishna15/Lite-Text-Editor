import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var editor: EditorController
    @Binding var selectedCountMetric: DocumentCountMetric
    @State private var isCountMenuHovered = false
    @State private var isZoomMenuHovered = false

    var body: some View {
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
        .frame(height: 28)
        .padding(.horizontal, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
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
        Menu {
            ForEach(DocumentCountMetric.allCases) { metric in
                Button {
                    selectedCountMetric = metric
                } label: {
                    HStack {
                        Text(metric.menuText(for: editor.documentStatistics))

                        if selectedCountMetric == metric {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedCountMetric.statusText(for: editor.documentStatistics))
                    .font(ChromeStyle.smallTextFont)
                    .monospacedDigit()
                    .foregroundStyle(ChromeStyle.controlTextColor)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
            }
            .padding(.horizontal, 6)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCountMenuHovered ? ChromeStyle.toolbarHoverFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isCountMenuHovered ? ChromeStyle.toolbarHoverBorder : Color.clear,
                        lineWidth: isCountMenuHovered ? 1 : 0
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isCountMenuHovered = $0 }
        .fixedSize()
        .help("Document Counts")
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Menu {
                Button(DocumentZoomPreset.fitPage.title) {
                    editor.fitPageToScreen()
                }

                Divider()

                ForEach(DocumentZoomPreset.fixedPresets) { preset in
                    Button(preset.title) {
                        editor.setZoomPreset(preset)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(editor.zoomDisplayText)
                        .font(ChromeStyle.smallTextFont)
                        .monospacedDigit()
                        .foregroundStyle(ChromeStyle.controlTextColor)
                        .frame(width: 42, alignment: .trailing)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                }
                .padding(.horizontal, 5)
                .frame(height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isZoomMenuHovered ? ChromeStyle.toolbarHoverFill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            isZoomMenuHovered ? ChromeStyle.toolbarHoverBorder : Color.clear,
                            lineWidth: isZoomMenuHovered ? 1 : 0
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .onHover { isZoomMenuHovered = $0 }
            .fixedSize()
            .help("Zoom Size")

            StatusBarIconButton(symbol: "minus", help: "Zoom Out") {
                editor.zoomOut()
            }

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

            StatusBarIconButton(symbol: "plus", help: "Zoom In") {
                editor.zoomIn()
            }
        }
        .frame(height: 22)
        .layoutPriority(2)
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
