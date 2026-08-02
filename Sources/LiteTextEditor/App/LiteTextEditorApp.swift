import AppKit
import SwiftUI

#if !arch(arm64)
#error("Lite Text Editor only supports Apple Silicon arm64 builds.")
#endif

final class QuitConfirmationResponse {
    var reply: NSApplication.TerminateReply = .terminateNow
}

@main
final class LiteTextEditorApplication: NSObject, NSApplicationDelegate {
    private static let minimumWindowSize = NSSize(width: 960, height: 600)

    private var window: NSWindow?
    private var titlebarAccessoryController: NSTitlebarAccessoryViewController?
    private var appDelegateRetainer: LiteTextEditorApplication?
    private let recentDocumentStore = RecentDocumentStore()
    private weak var openRecentMenu: NSMenu?
    private var didConfirmWindowClose = false

    static func main() {
        let app = NSApplication.shared
        let delegate = LiteTextEditorApplication()

        app.delegate = delegate
        app.appearance = ChromeStyle.appearance
        delegate.configureApplicationIcon(for: app)
        app.setActivationPolicy(.regular)
        delegate.appDelegateRetainer = delegate
        delegate.configureMainMenu()
        NotificationCenter.default.addObserver(
            delegate,
            selector: #selector(recentDocumentsChanged),
            name: .liteTextEditorRecentDocumentsChanged,
            object: nil
        )
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let minimumWindowSize = Self.minimumWindowSize
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let initialWindowSize = NSSize(
            width: min(1280, max(minimumWindowSize.width, visibleFrame.width * 0.88)),
            height: min(760, max(minimumWindowSize.height, visibleFrame.height * 0.86))
        )

        let editor = EditorController()
        editor.prepareTitleForLastRestorableDocument()
        let hostingView = NSHostingView(
            rootView: EditorView(editor: editor)
                .frame(
                    minWidth: minimumWindowSize.width,
                    minHeight: minimumWindowSize.height,
                    alignment: .topLeading
                )
        )
        hostingView.appearance = ChromeStyle.appearance

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = ChromeStyle.windowTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = ChromeStyle.appearance
        window.contentMinSize = minimumWindowSize
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumWindowSize)).size
        window.setFrameAutosaveName("LiteTextEditorMainWindow")
        window.setContentSize(clampedContentSize(for: window, minimumSize: minimumWindowSize))
        window.center()
        window.contentView = hostingView
        window.delegate = self
        installTitlebarChrome(for: window, editor: editor)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func configureApplicationIcon(for app: NSApplication) {
        guard let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
              let iconImage = NSImage(contentsOf: iconURL) else {
            return
        }

        app.applicationIconImage = iconImage
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if didConfirmWindowClose {
            return .terminateNow
        }

        return requestQuitConfirmation()
    }

    private func clampedContentSize(for window: NSWindow, minimumSize: NSSize) -> NSSize {
        let currentContentSize = window.contentLayoutRect.size

        return NSSize(
            width: max(currentContentSize.width, minimumSize.width),
            height: max(currentContentSize.height, minimumSize.height)
        )
    }

    private func installTitlebarChrome(for window: NSWindow, editor: EditorController) {
        let size = NSSize(
            width: TitlebarEditorChromeLayout.width,
            height: TitlebarEditorChromeLayout.height
        )
        let hostingView = NSHostingView(rootView: TitlebarEditorChromeView(editor: editor))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.appearance = ChromeStyle.appearance
        hostingView.wantsLayer = false

        let accessoryController = NSTitlebarAccessoryViewController()
        accessoryController.layoutAttribute = .left
        accessoryController.preferredContentSize = size
        accessoryController.view = hostingView
        window.addTitlebarAccessoryViewController(accessoryController)

        titlebarAccessoryController = accessoryController
    }

    @objc private func openDocument() {
        NotificationCenter.default.post(name: .liteTextEditorOpenDocument, object: nil)
    }

    @objc private func newDocument() {
        NotificationCenter.default.post(name: .liteTextEditorNewDocument, object: nil)
    }

    @objc private func openRecentDocument(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NotificationCenter.default.post(
            name: .liteTextEditorOpenRecentDocument,
            object: URL(fileURLWithPath: path)
        )
    }

    @objc private func clearRecentDocuments() {
        recentDocumentStore.clear()
        updateOpenRecentMenu()
    }

    @objc private func recentDocumentsChanged() {
        updateOpenRecentMenu()
    }

    @objc private func saveDocument() {
        NotificationCenter.default.post(name: .liteTextEditorSaveDocument, object: nil)
    }

    @objc private func saveDocumentAs() {
        NotificationCenter.default.post(name: .liteTextEditorSaveDocumentAs, object: nil)
    }

    @objc private func exportPDF() {
        NotificationCenter.default.post(name: .liteTextEditorExportPDF, object: nil)
    }

    @objc private func printDocument() {
        NotificationCenter.default.post(name: .liteTextEditorPrintDocument, object: nil)
    }

    @objc private func findPanelAction(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorFindPanelAction, object: sender.tag)
    }

    @objc private func showLiteTextEditorHelp() {
        let alert = NSAlert()
        alert.messageText = "Lite Text Editor Help"
        alert.informativeText = "Use the compact tabs beside the traffic lights to switch sections. Press + to add Tab 2, Tab 3, and so on; double-click or right-click a tab to rename it. Outline and simple formatting controls are also in the titlebar. All document text uses Courier automatically."
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func showSettings() {
        NotificationCenter.default.post(name: .liteTextEditorShowSettings, object: nil)
    }

    @objc private func beginSpellingReview() {
        NotificationCenter.default.post(name: .liteTextEditorBeginSpellingReview, object: nil)
    }

    @objc private func acceptSuggestion() {
        NotificationCenter.default.post(name: .liteTextEditorAcceptSuggestion, object: nil)
    }

    @objc private func toggleBold() {
        NotificationCenter.default.post(name: .liteTextEditorToggleBold, object: nil)
    }

    @objc private func toggleItalic() {
        NotificationCenter.default.post(name: .liteTextEditorToggleItalic, object: nil)
    }

    @objc private func toggleUnderline() {
        NotificationCenter.default.post(name: .liteTextEditorToggleUnderline, object: nil)
    }

    @objc private func toggleStrikethrough() {
        NotificationCenter.default.post(name: .liteTextEditorToggleStrikethrough, object: nil)
    }

    @objc private func setBaseline(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetBaseline, object: sender.representedObject)
    }

    @objc private func toggleHighlight() {
        NotificationCenter.default.post(name: .liteTextEditorToggleHighlight, object: nil)
    }

    @objc private func setHighlightColor(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetHighlightColor, object: sender.representedObject)
    }

    @objc private func clearTextColor() {
        NotificationCenter.default.post(name: .liteTextEditorClearTextColor, object: nil)
    }

    @objc private func copyFormatting() {
        NotificationCenter.default.post(name: .liteTextEditorCopyFormatting, object: nil)
    }

    @objc private func pasteFormatting() {
        NotificationCenter.default.post(name: .liteTextEditorPasteFormatting, object: nil)
    }

    @objc private func applyTextCasing(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorApplyTextCasing, object: sender.representedObject)
    }

    @objc private func setCharacterSpacing(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetCharacterSpacing, object: sender.representedObject)
    }

    @objc private func clearFormatting() {
        NotificationCenter.default.post(name: .liteTextEditorClearFormatting, object: nil)
    }

    @objc private func setTextPreset(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetTextPreset, object: sender.representedObject)
    }

    @objc private func toggleBulletedList() {
        NotificationCenter.default.post(name: .liteTextEditorToggleBulletedList, object: nil)
    }

    @objc private func toggleNumberedList() {
        NotificationCenter.default.post(name: .liteTextEditorToggleNumberedList, object: nil)
    }

    @objc private func toggleChecklist() {
        NotificationCenter.default.post(name: .liteTextEditorToggleChecklist, object: nil)
    }

    @objc private func setListStyle(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetListStyle, object: sender.representedObject)
    }

    @objc private func applyListNumberingAction(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorApplyListNumberingAction, object: sender.representedObject)
    }

    @objc private func increaseIndent() {
        NotificationCenter.default.post(name: .liteTextEditorIncreaseIndent, object: nil)
    }

    @objc private func decreaseIndent() {
        NotificationCenter.default.post(name: .liteTextEditorDecreaseIndent, object: nil)
    }

    @objc private func alignLeft() {
        NotificationCenter.default.post(name: .liteTextEditorAlignLeft, object: nil)
    }

    @objc private func alignCenter() {
        NotificationCenter.default.post(name: .liteTextEditorAlignCenter, object: nil)
    }

    @objc private func alignRight() {
        NotificationCenter.default.post(name: .liteTextEditorAlignRight, object: nil)
    }

    @objc private func justifyText() {
        NotificationCenter.default.post(name: .liteTextEditorJustifyText, object: nil)
    }

    @objc private func setLineSpacing(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetLineSpacing, object: sender.representedObject)
    }

    @objc private func applyParagraphSpacing(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorApplyParagraphSpacing, object: sender.representedObject)
    }

    @objc private func applyParagraphIndent(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorApplyParagraphIndent, object: sender.representedObject)
    }

    @objc private func toggleKeepParagraphTogether() {
        NotificationCenter.default.post(name: .liteTextEditorToggleKeepParagraphTogether, object: nil)
    }

    @objc private func toggleKeepWithNext() {
        NotificationCenter.default.post(name: .liteTextEditorToggleKeepWithNext, object: nil)
    }

    @objc private func zoomIn() {
        NotificationCenter.default.post(name: .liteTextEditorZoomIn, object: nil)
    }

    @objc private func zoomOut() {
        NotificationCenter.default.post(name: .liteTextEditorZoomOut, object: nil)
    }

    @objc private func fitPageToScreen() {
        NotificationCenter.default.post(name: .liteTextEditorZoomFitPage, object: nil)
    }

    @objc private func actualSize() {
        NotificationCenter.default.post(name: .liteTextEditorZoomActualSize, object: nil)
    }

    @objc private func toggleOutline() {
        NotificationCenter.default.post(name: .liteTextEditorToggleOutline, object: nil)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Lite Text Editor")
        appMenu.addItem(commandItem("Settings...", action: #selector(showSettings), key: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Lite Text Editor",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(commandItem("New", action: #selector(newDocument), key: "n"))
        fileMenu.addItem(commandItem("Open...", action: #selector(openDocument), key: "o"))

        let openRecentMenuItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.delegate = self
        openRecentMenuItem.submenu = openRecentMenu
        fileMenu.addItem(openRecentMenuItem)
        self.openRecentMenu = openRecentMenu

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(commandItem("Save", action: #selector(saveDocument), key: "s"))
        fileMenu.addItem(commandItem("Save As...", action: #selector(saveDocumentAs), key: "S"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(commandItem("Export PDF...", action: #selector(exportPDF), key: "e", modifiers: [.command, .shift]))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(commandItem("Print...", action: #selector(printDocument), key: "p"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.addItem(NSMenuItem.separator())

        let findMenuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        findMenu.addItem(findCommandItem("Find...", action: .showFindInterface, key: "f"))
        findMenu.addItem(findCommandItem("Find and Replace...", action: .showReplaceInterface, key: "f", modifiers: [.command, .option]))
        findMenu.addItem(NSMenuItem.separator())
        findMenu.addItem(findCommandItem("Find Next", action: .nextMatch, key: "g"))
        findMenu.addItem(findCommandItem("Find Previous", action: .previousMatch, key: "G"))
        findMenu.addItem(findCommandItem("Use Selection for Find", action: .setSearchString, key: "e"))
        findMenuItem.submenu = findMenu
        editMenu.addItem(findMenuItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let homeMenuItem = NSMenuItem()
        let homeMenu = NSMenu(title: "Home")
        let stylesMenuItem = NSMenuItem(title: "Styles", action: nil, keyEquivalent: "")
        let stylesMenu = NSMenu(title: "Styles")
        TextPreset.allCases.forEach { preset in
            let item = NSMenuItem(title: preset.title, action: #selector(setTextPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            stylesMenu.addItem(item)
        }
        stylesMenuItem.submenu = stylesMenu
        homeMenu.addItem(stylesMenuItem)
        homeMenu.addItem(NSMenuItem.separator())
        homeMenu.addItem(NSMenuItem(title: "Show Colors", action: NSSelectorFromString("orderFrontColorPanel:"), keyEquivalent: "c"))
        homeMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        homeMenu.addItem(NSMenuItem.separator())
        homeMenu.addItem(commandItem("Bold", action: #selector(toggleBold), key: "b"))
        homeMenu.addItem(commandItem("Italic", action: #selector(toggleItalic), key: "i"))
        homeMenu.addItem(commandItem("Underline", action: #selector(toggleUnderline), key: "u"))
        homeMenu.addItem(commandItem("Strikethrough", action: #selector(toggleStrikethrough), key: "x", modifiers: [.command, .shift]))
        homeMenu.addItem(optionMenuItem("Baseline", options: TextBaselineOption.allCases, action: #selector(setBaseline(_:))))
        homeMenu.addItem(commandItem("Highlight", action: #selector(toggleHighlight), key: "h", modifiers: [.command, .shift]))
        homeMenu.addItem(optionMenuItem("Highlight Color", options: HighlightColorOption.allCases, action: #selector(setHighlightColor(_:))))
        homeMenu.addItem(commandItem("Clear Text Color", action: #selector(clearTextColor), key: "", modifiers: []))
        homeMenu.addItem(NSMenuItem.separator())
        homeMenu.addItem(commandItem("Copy Formatting", action: #selector(copyFormatting), key: "c", modifiers: [.command, .option]))
        homeMenu.addItem(commandItem("Paste Formatting", action: #selector(pasteFormatting), key: "v", modifiers: [.command, .option]))
        homeMenu.addItem(optionMenuItem("Change Case", options: TextCasingOption.allCases, action: #selector(applyTextCasing(_:))))
        homeMenu.addItem(optionMenuItem("Character Spacing", options: CharacterSpacingOption.allCases, action: #selector(setCharacterSpacing(_:))))
        homeMenu.addItem(commandItem("Clear Formatting", action: #selector(clearFormatting), key: "\\", modifiers: [.command]))
        homeMenu.addItem(NSMenuItem.separator())
        homeMenu.addItem(commandItem("Bulleted List", action: #selector(toggleBulletedList), key: "8", modifiers: [.command, .shift]))
        homeMenu.addItem(commandItem("Numbered List", action: #selector(toggleNumberedList), key: "7", modifiers: [.command, .shift]))
        homeMenu.addItem(commandItem("Checklist", action: #selector(toggleChecklist), key: "9", modifiers: [.command, .shift]))
        homeMenu.addItem(optionMenuItem("List Style", options: ListStyleOption.allCases, action: #selector(setListStyle(_:))))
        homeMenu.addItem(optionMenuItem("Numbering", options: ListNumberingAction.allCases, action: #selector(applyListNumberingAction(_:))))
        homeMenuItem.submenu = homeMenu
        mainMenu.addItem(homeMenuItem)

        let insertMenuItem = NSMenuItem()
        let insertMenu = NSMenu(title: "Insert")
        insertMenu.addItem(commandItem("Insert Autocomplete Word", action: #selector(acceptSuggestion), key: "", modifiers: []))
        insertMenuItem.submenu = insertMenu
        mainMenu.addItem(insertMenuItem)

        let layoutMenuItem = NSMenuItem()
        let layoutMenu = NSMenu(title: "Layout")
        layoutMenu.addItem(commandItem("Align Left", action: #selector(alignLeft), key: "l"))
        layoutMenu.addItem(commandItem("Center", action: #selector(alignCenter), key: "", modifiers: []))
        layoutMenu.addItem(commandItem("Align Right", action: #selector(alignRight), key: "r"))
        layoutMenu.addItem(commandItem("Justify", action: #selector(justifyText), key: "j"))
        layoutMenu.addItem(NSMenuItem.separator())
        layoutMenu.addItem(optionMenuItem("Line Spacing", options: LineSpacingOption.allCases, action: #selector(setLineSpacing(_:))))
        layoutMenu.addItem(optionMenuItem("Paragraph Spacing", options: ParagraphSpacingOption.allCases, action: #selector(applyParagraphSpacing(_:))))
        layoutMenu.addItem(optionMenuItem("Paragraph Indents", options: ParagraphIndentOption.allCases, action: #selector(applyParagraphIndent(_:))))
        layoutMenu.addItem(NSMenuItem.separator())
        layoutMenu.addItem(commandItem("Decrease Indent", action: #selector(decreaseIndent), key: "["))
        layoutMenu.addItem(commandItem("Increase Indent", action: #selector(increaseIndent), key: "]"))
        layoutMenuItem.submenu = layoutMenu
        mainMenu.addItem(layoutMenuItem)

        let reviewMenuItem = NSMenuItem()
        let reviewMenu = NSMenu(title: "Review")
        reviewMenu.addItem(commandItem("Spelling Review", action: #selector(beginSpellingReview), key: "x", modifiers: [.command, .option]))
        reviewMenu.addItem(NSMenuItem.separator())
        reviewMenu.addItem(NSMenuItem(title: "Show Spelling and Grammar", action: NSSelectorFromString("showGuessPanel:"), keyEquivalent: ":"))
        reviewMenu.addItem(NSMenuItem(title: "Check Document Now", action: NSSelectorFromString("checkSpelling:"), keyEquivalent: ";"))
        reviewMenu.addItem(NSMenuItem.separator())
        reviewMenu.addItem(NSMenuItem(title: "Check Spelling While Typing", action: NSSelectorFromString("toggleContinuousSpellChecking:"), keyEquivalent: ""))
        reviewMenu.addItem(NSMenuItem(title: "Check Grammar With Spelling", action: NSSelectorFromString("toggleGrammarChecking:"), keyEquivalent: ""))
        reviewMenuItem.submenu = reviewMenu
        mainMenu.addItem(reviewMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(commandItem("Toggle Outline", action: #selector(toggleOutline), key: "1", modifiers: [.command, .option]))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(commandItem("Zoom In", action: #selector(zoomIn), key: "="))
        viewMenu.addItem(commandItem("Zoom Out", action: #selector(zoomOut), key: "-"))
        viewMenu.addItem(commandItem("Actual Size", action: #selector(actualSize), key: "0"))
        viewMenu.addItem(commandItem("Fit Page", action: #selector(fitPageToScreen), key: "0", modifiers: [.command, .option]))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
        viewMenu.items.last?.keyEquivalentModifierMask = [.control, .command]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(commandItem("Lite Text Editor Help", action: #selector(showLiteTextEditorHelp), key: "?"))
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApplication.shared.mainMenu = mainMenu
        updateOpenRecentMenu()
    }

    private func updateOpenRecentMenu() {
        guard let openRecentMenu else { return }

        openRecentMenu.removeAllItems()

        let recentURLs = recentDocumentStore.load()
        guard !recentURLs.isEmpty else {
            let emptyItem = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            openRecentMenu.addItem(emptyItem)
            return
        }

        recentURLs.forEach { url in
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentDocument(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url.path
            item.toolTip = url.path
            openRecentMenu.addItem(item)
        }

        openRecentMenu.addItem(NSMenuItem.separator())
        openRecentMenu.addItem(NSMenuItem(title: "Clear Menu", action: #selector(clearRecentDocuments), keyEquivalent: ""))
        openRecentMenu.items.last?.target = self
    }

    private func commandItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private func findCommandItem(
        _ title: String,
        action: NSTextFinder.Action,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = commandItem(title, action: #selector(findPanelAction(_:)), key: key, modifiers: modifiers)
        item.tag = action.rawValue
        return item
    }

    private func optionMenuItem<Option: RawRepresentable & MenuTitledOption>(
        _ title: String,
        options: [Option],
        action: Selector
    ) -> NSMenuItem where Option.RawValue == String {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)

        options.forEach { option in
            let item = commandItem(option.title, action: action, key: "", modifiers: [])
            item.representedObject = option.rawValue
            menu.addItem(item)
        }

        menuItem.submenu = menu
        return menuItem
    }

    private func requestQuitConfirmation() -> NSApplication.TerminateReply {
        let response = QuitConfirmationResponse()
        NotificationCenter.default.post(name: .liteTextEditorConfirmQuit, object: response)
        return response.reply
    }
}

extension LiteTextEditorApplication: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let response = requestQuitConfirmation()
        didConfirmWindowClose = response == .terminateNow
        return didConfirmWindowClose
    }
}

extension LiteTextEditorApplication: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === openRecentMenu {
            updateOpenRecentMenu()
        }
    }
}

extension Notification.Name {
    static let liteTextEditorNewDocument = Notification.Name("liteTextEditorNewDocument")
    static let liteTextEditorOpenDocument = Notification.Name("liteTextEditorOpenDocument")
    static let liteTextEditorOpenRecentDocument = Notification.Name("liteTextEditorOpenRecentDocument")
    static let liteTextEditorSaveDocument = Notification.Name("liteTextEditorSaveDocument")
    static let liteTextEditorSaveDocumentAs = Notification.Name("liteTextEditorSaveDocumentAs")
    static let liteTextEditorConfirmQuit = Notification.Name("liteTextEditorConfirmQuit")
    static let liteTextEditorExportPDF = Notification.Name("liteTextEditorExportPDF")
    static let liteTextEditorPrintDocument = Notification.Name("liteTextEditorPrintDocument")
    static let liteTextEditorFindPanelAction = Notification.Name("liteTextEditorFindPanelAction")
    static let liteTextEditorShowSettings = Notification.Name("liteTextEditorShowSettings")
    static let liteTextEditorBeginSpellingReview = Notification.Name("liteTextEditorBeginSpellingReview")
    static let liteTextEditorAcceptSuggestion = Notification.Name("liteTextEditorAcceptSuggestion")
    static let liteTextEditorToggleBold = Notification.Name("liteTextEditorToggleBold")
    static let liteTextEditorToggleItalic = Notification.Name("liteTextEditorToggleItalic")
    static let liteTextEditorToggleUnderline = Notification.Name("liteTextEditorToggleUnderline")
    static let liteTextEditorToggleStrikethrough = Notification.Name("liteTextEditorToggleStrikethrough")
    static let liteTextEditorSetBaseline = Notification.Name("liteTextEditorSetBaseline")
    static let liteTextEditorToggleHighlight = Notification.Name("liteTextEditorToggleHighlight")
    static let liteTextEditorSetHighlightColor = Notification.Name("liteTextEditorSetHighlightColor")
    static let liteTextEditorClearTextColor = Notification.Name("liteTextEditorClearTextColor")
    static let liteTextEditorCopyFormatting = Notification.Name("liteTextEditorCopyFormatting")
    static let liteTextEditorPasteFormatting = Notification.Name("liteTextEditorPasteFormatting")
    static let liteTextEditorApplyTextCasing = Notification.Name("liteTextEditorApplyTextCasing")
    static let liteTextEditorSetCharacterSpacing = Notification.Name("liteTextEditorSetCharacterSpacing")
    static let liteTextEditorClearFormatting = Notification.Name("liteTextEditorClearFormatting")
    static let liteTextEditorSetTextPreset = Notification.Name("liteTextEditorSetTextPreset")
    static let liteTextEditorToggleBulletedList = Notification.Name("liteTextEditorToggleBulletedList")
    static let liteTextEditorToggleNumberedList = Notification.Name("liteTextEditorToggleNumberedList")
    static let liteTextEditorToggleChecklist = Notification.Name("liteTextEditorToggleChecklist")
    static let liteTextEditorSetListStyle = Notification.Name("liteTextEditorSetListStyle")
    static let liteTextEditorApplyListNumberingAction = Notification.Name("liteTextEditorApplyListNumberingAction")
    static let liteTextEditorIncreaseIndent = Notification.Name("liteTextEditorIncreaseIndent")
    static let liteTextEditorDecreaseIndent = Notification.Name("liteTextEditorDecreaseIndent")
    static let liteTextEditorAlignLeft = Notification.Name("liteTextEditorAlignLeft")
    static let liteTextEditorAlignCenter = Notification.Name("liteTextEditorAlignCenter")
    static let liteTextEditorAlignRight = Notification.Name("liteTextEditorAlignRight")
    static let liteTextEditorJustifyText = Notification.Name("liteTextEditorJustifyText")
    static let liteTextEditorSetLineSpacing = Notification.Name("liteTextEditorSetLineSpacing")
    static let liteTextEditorApplyParagraphSpacing = Notification.Name("liteTextEditorApplyParagraphSpacing")
    static let liteTextEditorApplyParagraphIndent = Notification.Name("liteTextEditorApplyParagraphIndent")
    static let liteTextEditorToggleKeepParagraphTogether = Notification.Name("liteTextEditorToggleKeepParagraphTogether")
    static let liteTextEditorToggleKeepWithNext = Notification.Name("liteTextEditorToggleKeepWithNext")
    static let liteTextEditorZoomIn = Notification.Name("liteTextEditorZoomIn")
    static let liteTextEditorZoomOut = Notification.Name("liteTextEditorZoomOut")
    static let liteTextEditorZoomFitPage = Notification.Name("liteTextEditorZoomFitPage")
    static let liteTextEditorZoomActualSize = Notification.Name("liteTextEditorZoomActualSize")
    static let liteTextEditorToggleOutline = Notification.Name("liteTextEditorToggleOutline")
    static let liteTextEditorRecentDocumentsChanged = Notification.Name("liteTextEditorRecentDocumentsChanged")
}
