import SwiftUI

enum TitlebarEditorChromeLayout {
    static let width: CGFloat = 640
    static let height: CGFloat = 24
    static let dividerHeight: CGFloat = 14
    static let dividerWidth: CGFloat = 1
    static let sectionSpacing: CGFloat = 8
    static let minimumFormattingControlsWidth: CGFloat = 96

    static var minimumContentWidth: CGFloat {
        TitlebarDocumentTabsLayout.sectionWidth
            + TitlebarDocumentTitleLayout.maximumWidth
            + minimumFormattingControlsWidth
            + (dividerWidth * 2)
            + (sectionSpacing * 4)
    }
}

enum TitlebarDocumentTabsLayout {
    static let stripWidth: CGFloat = 320
    static let tabHeight: CGFloat = 18
    static let maximumTabWidth: CGFloat = 88
    static let addButtonSize: CGFloat = 20
    static let addButtonSpacing: CGFloat = 4
    static let tabSpacing: CGFloat = 3
    static let cornerRadius: CGFloat = 6

    static var sectionWidth: CGFloat {
        stripWidth + addButtonSpacing + addButtonSize
    }
}

struct TitlebarEditorChromeView: View {
    @ObservedObject var editor: EditorController

    var body: some View {
        HStack(spacing: TitlebarEditorChromeLayout.sectionSpacing) {
            TitlebarDocumentTabsView(editor: editor)
            titlebarDivider
            TitlebarDocumentTitleView(editor: editor)
            titlebarDivider
            TitlebarFormattingControlsView(editor: editor)
        }
        .frame(
            width: TitlebarEditorChromeLayout.width,
            height: TitlebarEditorChromeLayout.height,
            alignment: .leading
        )
    }

    private var titlebarDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.68))
            .frame(
                width: TitlebarEditorChromeLayout.dividerWidth,
                height: TitlebarEditorChromeLayout.dividerHeight
            )
            .accessibilityHidden(true)
    }
}

private struct TitlebarDocumentTabsView: View {
    @ObservedObject var editor: EditorController

    var body: some View {
        HStack(spacing: TitlebarDocumentTabsLayout.addButtonSpacing) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TitlebarDocumentTabsLayout.tabSpacing) {
                        ForEach(editor.documentTabs) { tab in
                            TitlebarDocumentTabButton(
                                tab: tab,
                                isSelected: editor.selectedDocumentTabID == tab.id,
                                canClose: editor.canCloseDocumentTab,
                                onSelect: { editor.selectDocumentTab(tab.id) },
                                onRename: { editor.promptToRenameDocumentTab(tab.id) },
                                onDuplicate: { editor.duplicateDocumentTab(tab.id) },
                                onClose: { editor.requestCloseDocumentTab(tab.id) }
                            )
                            .id(tab.id)
                        }
                    }
                    .frame(height: TitlebarEditorChromeLayout.height)
                }
                .frame(
                    width: TitlebarDocumentTabsLayout.stripWidth,
                    height: TitlebarEditorChromeLayout.height
                )
                .onAppear {
                    scrollToSelectedTab(using: proxy, animated: false)
                }
                .onChange(of: editor.selectedDocumentTabID) { _ in
                    scrollToSelectedTab(using: proxy, animated: true)
                }
            }

            TitlebarIconButton(symbol: "plus", help: "Add document tab") {
                editor.addDocumentTab()
            }
        }
        .frame(height: TitlebarEditorChromeLayout.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document tabs")
    }

    private func scrollToSelectedTab(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedDocumentTabID = editor.selectedDocumentTabID else { return }

        let scroll = {
            proxy.scrollTo(selectedDocumentTabID, anchor: .trailing)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.16), scroll)
        } else {
            scroll()
        }
    }
}

private struct TitlebarDocumentTabButton: View {
    let tab: DocumentTabDescriptor
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.accentColor : ChromeStyle.controlTextColor)
                .padding(.horizontal, 7)
                .frame(maxWidth: TitlebarDocumentTabsLayout.maximumTabWidth)
                .frame(height: TitlebarDocumentTabsLayout.tabHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: TitlebarDocumentTabsLayout.cornerRadius, style: .continuous)
                .fill(tabBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TitlebarDocumentTabsLayout.cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.38) : Color.clear,
                    lineWidth: 0.5
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: TitlebarDocumentTabsLayout.cornerRadius, style: .continuous))
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded(onRename)
        )
        .contextMenu {
            Button("Rename Tab…", action: onRename)
            Button("Duplicate Tab", action: onDuplicate)
            Divider()
            Button("Close Tab", role: .destructive, action: onClose)
                .disabled(!canClose)
        }
        .help("\(tab.title) — double-click or right-click to rename")
        .accessibilityLabel("Document tab \(tab.title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tabBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        }

        return isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.025)
    }
}

private struct TitlebarFormattingControlsView: View {
    @ObservedObject var editor: EditorController

    var body: some View {
        HStack(spacing: 2) {
            TitlebarIconButton(
                symbol: "sidebar.left",
                help: editor.isOutlineVisible ? "Hide Outline" : "Show Outline",
                isSelected: editor.isOutlineVisible
            ) {
                withAnimation(ChromeStyle.outlinePanelAnimation) {
                    editor.isOutlineVisible.toggle()
                }
            }

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.60))
                .frame(width: 1, height: 12)
                .padding(.horizontal, 2)
                .accessibilityHidden(true)

            TitlebarIconButton(
                symbol: "bold",
                help: "Bold",
                isSelected: editor.formattingState.isBold,
                action: editor.toggleBold
            )

            TitlebarIconButton(
                symbol: "italic",
                help: "Italic",
                isSelected: editor.formattingState.isItalic,
                action: editor.toggleItalic
            )

            TitlebarIconButton(
                symbol: "underline",
                help: "Underline",
                isSelected: editor.formattingState.isUnderline,
                action: editor.toggleUnderline
            )
        }
        .frame(height: TitlebarEditorChromeLayout.height)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: TitlebarEditorChromeLayout.minimumFormattingControlsWidth)
    }
}

private struct TitlebarIconButton: View {
    let symbol: String
    let help: String
    var isSelected: Bool? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected == true ? Color.accentColor : ChromeStyle.controlTextColor)
                .frame(
                    width: TitlebarDocumentTabsLayout.addButtonSize,
                    height: TitlebarDocumentTabsLayout.addButtonSize
                )
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(buttonBackground)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
        .modifier(ToggleStateAccessibilityModifier(isSelected: isSelected))
    }

    private var buttonBackground: Color {
        if isSelected == true {
            return Color.accentColor.opacity(0.15)
        }

        return isHovered ? Color.primary.opacity(0.07) : Color.clear
    }
}

private struct ToggleStateAccessibilityModifier: ViewModifier {
    let isSelected: Bool?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let isSelected {
            content.accessibilityValue(isSelected ? "On" : "Off")
        } else {
            content
        }
    }
}
