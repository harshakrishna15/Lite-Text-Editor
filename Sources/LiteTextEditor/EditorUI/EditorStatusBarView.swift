import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var editor: EditorController

    var body: some View {
        ChromeGlassContainer(spacing: 8) {
            HStack(spacing: 12) {
                documentStatisticsText

                Spacer()

                predictionStatusText
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
            .frame(maxWidth: 180, alignment: .trailing)
            .help(statusText)
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

    private var predictionTint: Color {
        switch editor.predictionState {
        case .predicting:
            return Color.accentColor
        default:
            return ChromeStyle.secondaryTextColor
        }
    }
}
