import SwiftUI

struct TitlebarDocumentTitleView: View {
    @ObservedObject var editor: EditorController
    @State private var titleState: TitlebarDocumentTitleState
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    init(editor: EditorController) {
        self.editor = editor
        _titleState = State(initialValue: TitlebarDocumentTitleState(documentTitle: editor.documentTitle))
    }

    var body: some View {
        titleContent
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
            .padding(.horizontal, 8)
            .background(titleBackground)
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .onHover { isHovered = $0 }
            .onChange(of: editor.documentTitle) { title in
                titleState.syncDocumentTitle(title, isFocused: isFocused)
            }
            .onChange(of: isFocused) { focused in
                if !focused {
                    commitTitle()
                }
            }
            .animation(nil, value: isHovered)
            .animation(nil, value: isFocused)
            .help("Document Title")
    }

    @ViewBuilder
    private var titleContent: some View {
        if isFocused {
            titleEditor
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Text(titleState.displayTitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ChromeStyle.controlTextColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                isFocused = true
            }
    }

    private var titleEditor: some View {
        TextField("Untitled", text: $titleState.draftTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ChromeStyle.controlTextColor)
            .multilineTextAlignment(TitlebarDocumentTitleLayout.textAlignment)
            .lineLimit(1)
            .truncationMode(.middle)
            .focused($isFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onSubmit(commitTitle)
            .onAppear {
                isFocused = true
            }
    }

    @ViewBuilder
    private var titleBackground: some View {
        if isFocused || isHovered {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isFocused ? 0.9 : 0.55))
        }
    }

    private func commitTitle() {
        editor.commitDocumentTitle(titleState.draftTitle)
        titleState.syncDocumentTitle(editor.documentTitle, isFocused: false)
    }
}
