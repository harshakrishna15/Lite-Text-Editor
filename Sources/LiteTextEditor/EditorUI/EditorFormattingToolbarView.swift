import SwiftUI

struct EditorFormattingToolbarView: View {
    @ObservedObject var editor: EditorController
    @Binding var isOutlineVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            ChromeGlassContainer(spacing: ChromeStyle.toolbarSectionSpacing) {
                formattingBar
                    .frame(height: ChromeStyle.toolbarPanelHeight)
                    .chromeGlassBackground(
                        .toolbar,
                        in: RoundedRectangle(cornerRadius: ChromeStyle.toolbarPanelCornerRadius, style: .continuous)
                    )
                    .chromeFloatingPanelShadow()
                    .frame(
                        maxWidth: max(0, proxy.size.width - (ChromeStyle.toolbarFloatingHorizontalMargin * 2)),
                        maxHeight: .infinity,
                        alignment: .top
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, ChromeStyle.toolbarFloatingTopPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: ChromeStyle.regularToolbarHeight)
    }

    private var formattingBar: some View {
        HStack(alignment: .center, spacing: ChromeStyle.toolbarSectionSpacing) {
            outlineToggleButton
            ToolbarDivider()
            documentTabStrip
                .layoutPriority(1)
            addTabMenu
            Spacer(minLength: 6)
            ToolbarDivider()
            courierIndicator
            inlineFormattingSection
        }
        .padding(.horizontal, ChromeStyle.toolbarHorizontalPadding)
        .padding(.vertical, 4)
    }

    private var outlineToggleButton: some View {
        RibbonIconButton(
            symbol: "sidebar.left",
            help: isOutlineVisible ? "Hide Outline" : "Show Outline",
            isSelected: isOutlineVisible,
            isToggle: true
        ) {
            withAnimation(ChromeStyle.outlinePanelAnimation) {
                isOutlineVisible.toggle()
            }
        }
    }

    private var documentTabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(editor.documentTabs) { tab in
                        documentTabButton(tab)
                            .id(tab.id)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                scrollToSelectedTab(using: proxy, animated: false)
            }
            .onChange(of: editor.selectedDocumentTabID) { _ in
                scrollToSelectedTab(using: proxy, animated: true)
            }
        }
        .frame(minWidth: 120, maxWidth: .infinity)
        .help("Tabs in this document")
    }

    private func scrollToSelectedTab(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedDocumentTabID = editor.selectedDocumentTabID else { return }

        let scroll = {
            proxy.scrollTo(selectedDocumentTabID, anchor: .trailing)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.18), scroll)
        } else {
            scroll()
        }
    }

    private func documentTabButton(_ tab: DocumentTabDescriptor) -> some View {
        let isSelected = editor.selectedDocumentTabID == tab.id

        return HStack(spacing: 5) {
            Button {
                editor.selectDocumentTab(tab.id)
            } label: {
                Text(tab.title)
                    .font(.custom("Courier", size: 12).weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .frame(maxWidth: 132)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected && editor.canCloseDocumentTab {
                Button {
                    editor.requestCloseDocumentTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondary)
                .help("Close \(tab.title)")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, isSelected && editor.canCloseDocumentTab ? 6 : 10)
        .frame(height: ChromeStyle.toolbarControlHeight)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.30) : Color.clear, lineWidth: 1)
        }
        .contextMenu {
            Button("Rename Tab…") {
                editor.promptToRenameDocumentTab(tab.id)
            }
            Button("Duplicate Tab") {
                editor.duplicateDocumentTab(tab.id)
            }
            Divider()
            Button("Close Tab", role: .destructive) {
                editor.requestCloseDocumentTab(tab.id)
            }
            .disabled(!editor.canCloseDocumentTab)
        }
    }

    private var addTabMenu: some View {
        Menu {
            Button {
                editor.addDocumentTab(named: "Untitled")
            } label: {
                Label("Blank Tab", systemImage: "doc")
            }

            Button {
                editor.addDocumentTab(named: "Outline")
            } label: {
                Label("Outline", systemImage: "list.bullet.indent")
            }

            Button {
                editor.addDocumentTab(named: "Notes")
            } label: {
                Label("Notes", systemImage: "note.text")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: ChromeStyle.toolbarIconWidth, height: ChromeStyle.toolbarControlHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add a tab to this document")
    }

    private var courierIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat")
                .font(.system(size: 11, weight: .medium))
            Text(EditorTypography.displayName)
                .font(.custom("Courier", size: 12))
        }
        .foregroundStyle(Color.secondary)
        .padding(.horizontal, 8)
        .frame(height: ChromeStyle.toolbarControlHeight)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help("All document text uses Courier")
    }

    private var inlineFormattingSection: some View {
        ToolbarSection {
            RibbonIconButton(symbol: "bold", help: "Bold", isSelected: editor.formattingState.isBold, isToggle: true) {
                editor.toggleBold()
            }

            RibbonIconButton(symbol: "italic", help: "Italic", isSelected: editor.formattingState.isItalic, isToggle: true) {
                editor.toggleItalic()
            }

            RibbonIconButton(symbol: "underline", help: "Underline", isSelected: editor.formattingState.isUnderline, isToggle: true) {
                editor.toggleUnderline()
            }
        }
    }
}
