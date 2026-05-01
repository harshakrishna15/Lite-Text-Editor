import SwiftUI

struct TitlebarDocumentTitleView: View {
    @ObservedObject var editor: EditorController
    @State private var titleState: TitlebarDocumentTitleState
    @State private var isPopoverPresented = false
    @State private var isHovered = false

    init(editor: EditorController) {
        self.editor = editor
        _titleState = State(initialValue: TitlebarDocumentTitleState(documentTitle: editor.documentTitle))
    }

    var body: some View {
        Button {
            titleState.prepareForEditing(documentTitle: editor.documentTitle)
            isPopoverPresented = true
        } label: {
            titleLabel
        }
        .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
            .padding(.horizontal, 8)
            .background(titleBackground)
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .onHover { isHovered = $0 }
            .onChange(of: editor.documentTitle) { title in
                titleState.syncDocumentTitle(title, isEditing: isPopoverPresented)
            }
            .onChange(of: isPopoverPresented) { isPresented in
                if !isPresented {
                    commitTitle()
                }
            }
            .animation(nil, value: isHovered)
            .animation(nil, value: isPopoverPresented)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                TitlebarDocumentTitlePopover(
                    draftTitle: $titleState.draftTitle,
                    locationText: editor.documentLocationDisplayText,
                    onChooseLocation: {
                        editor.chooseDocumentSaveLocation()
                    },
                    onCommit: {
                        commitTitle()
                        isPopoverPresented = false
                    }
                )
            }
            .help("Document Title")
    }

    private var titleLabel: some View {
        HStack(spacing: 4) {
            Text(titleState.displayTitle)
                .lineLimit(1)
                .truncationMode(.middle)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ChromeStyle.secondaryTextColor)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(ChromeStyle.controlTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleBackground: some View {
        if isPopoverPresented || isHovered {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isPopoverPresented ? 0.9 : 0.55))
        }
    }

    private func commitTitle() {
        editor.commitDocumentTitle(titleState.draftTitle)
        titleState.syncDocumentTitle(editor.documentTitle, isEditing: false)
    }
}

private struct TitlebarDocumentTitlePopover: View {
    @Binding var draftTitle: String
    let locationText: String
    let onChooseLocation: () -> Void
    let onCommit: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Name:")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .frame(width: 54, alignment: .trailing)

                TextField("Untitled", text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .onSubmit(onCommit)
            }

            HStack(spacing: 10) {
                Text("Where:")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ChromeStyle.secondaryTextColor)
                    .frame(width: 54, alignment: .trailing)

                Button(action: onChooseLocation) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(ChromeStyle.secondaryTextColor)

                        Text(locationText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(ChromeStyle.controlTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ChromeStyle.secondaryTextColor)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .help("Choose Save Location")
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            isNameFocused = true
        }
    }
}
