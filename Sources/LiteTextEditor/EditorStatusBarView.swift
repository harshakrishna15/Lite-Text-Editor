import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var editor: EditorController
    @Binding var selectedCountMetric: DocumentCountMetric

    var body: some View {
        HStack(spacing: 12) {
            documentCountMenu

            StatusBarDivider()

            Text(editor.documentStatusText)
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 120, alignment: .leading)

            if !editor.activeStructureText.isEmpty {
                StatusBarDivider()

                Text(editor.activeStructureText)
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 180, alignment: .leading)
            }

            Spacer()

            zoomControls
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .windowBackgroundColor))
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
                    .frame(width: 190, alignment: .leading)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
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
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
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
            .frame(width: 150, height: 18)
            .controlSize(.small)
            .help("Zoom Slider")

            StatusBarIconButton(symbol: "plus", help: "Zoom In") {
                editor.zoomIn()
            }
        }
    }
}
