import SwiftUI

struct OutlineSidebarView: View {
    let items: [DocumentOutlineItem]
    let activeItemID: String?
    let summaryText: String
    let height: CGFloat
    let onSelect: (DocumentOutlineItem) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            outlineContent
        }
        .frame(width: ChromeStyle.outlinePanelWidth, height: height, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
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
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlColor).opacity(0.42))
                    )
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hide Outline")
            .help("Hide Outline")
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
            .padding(.bottom, 8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.leading, 6 + CGFloat(max(0, item.level - 1) * 12))
            .padding(.trailing, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(rowBackground)
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
