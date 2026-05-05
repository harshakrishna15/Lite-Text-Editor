import SwiftUI

struct OutlineSidebarView: View {
    let items: [DocumentOutlineItem]
    let activeItemID: String?
    let summaryText: String
    let metadata: DocumentStructureMetadata
    let height: CGFloat
    let onSelect: (DocumentOutlineItem) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            metadataHeader
            outlineContent
        }
        .frame(width: ChromeStyle.outlinePanelWidth, height: height, alignment: .top)
        .chromeGlassBackground(.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ChromeStyle.outlinePanelStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 14)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(ChromeStyle.controlSymbolFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)

            Text("Outline")
                .font(ChromeStyle.controlTextFont.weight(.semibold))
                .foregroundStyle(ChromeStyle.controlTextColor)

            if !items.isEmpty {
                Text(summaryText)
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: 104, alignment: .leading)
                    .frame(height: 18)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlColor).opacity(0.42))
                    )
            }

            Spacer()

            OutlineCloseButton(action: onClose)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }

    @ViewBuilder
    private var metadataHeader: some View {
        if metadata.hasStructure {
            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.displayTitle)
                    .font(ChromeStyle.smallTextFont.weight(.semibold))
                    .foregroundStyle(ChromeStyle.controlTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(metadata.summaryText)
                    .font(ChromeStyle.smallTextFont)
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlColor).opacity(0.22))

            Divider()
        }
    }

    private var outlineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(items) { item in
                        OutlineRow(
                            item: item,
                            isActive: activeItemID == item.id
                        ) {
                            onSelect(item)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No headings")
                .font(ChromeStyle.smallTextFont.weight(.semibold))
                .foregroundStyle(ChromeStyle.controlTextColor)

            Text("Use Title, Heading, or Subheading styles.")
                .font(ChromeStyle.smallTextFont)
                .foregroundStyle(ChromeStyle.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct OutlineRow: View {
    let item: DocumentOutlineItem
    let isActive: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 3)

                if !item.sectionNumber.isEmpty {
                    Text(item.sectionNumber)
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isActive ? Color.accentColor : ChromeStyle.secondaryTextColor)
                        .frame(minWidth: 22)
                        .frame(height: 18)
                        .padding(.horizontal, 4)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .controlColor).opacity(isActive ? 0.55 : 0.34))
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(rowFont)
                        .foregroundStyle(ChromeStyle.controlTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.detailText)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(ChromeStyle.secondaryTextColor)
                        .lineLimit(1)

                    Text(item.metadataText)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(ChromeStyle.secondaryTextColor.opacity(0.82))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.leading, 6 + CGFloat(max(0, item.level - 1) * 12))
            .padding(.trailing, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .chromeGlassControlBackground(
            isActive: true,
            isSelected: isActive,
            fallbackColor: rowBackground,
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isActive ? ChromeStyle.toolbarSelectedBorder : Color.clear, lineWidth: isActive ? 1 : 0)
        )
        .padding(.horizontal, 6)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(item.levelTitle): \(item.displayTitle)")
        .help(item.title)
    }

    private var rowBackground: Color {
        if isActive {
            return ChromeStyle.toolbarSelectedFill
        }

        return isHovered ? ChromeStyle.toolbarHoverFill : Color.clear
    }

    private var rowFont: Font {
        switch item.level {
        case 0:
            return ChromeStyle.smallTextFont.weight(.semibold)
        case 1:
            return ChromeStyle.smallTextFont
        default:
            return ChromeStyle.smallTextFont
        }
    }
}

private struct OutlineCloseButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovered ? ChromeStyle.controlTextColor : ChromeStyle.secondaryTextColor)
                .frame(width: 22, height: 22)
                .chromeGlassControlBackground(
                    isActive: true,
                    fallbackColor: isHovered ? ChromeStyle.toolbarHoverFill : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isHovered ? ChromeStyle.toolbarHoverBorder : Color.clear, lineWidth: isHovered ? 1 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Hide Outline")
        .help("Hide Outline")
    }
}
