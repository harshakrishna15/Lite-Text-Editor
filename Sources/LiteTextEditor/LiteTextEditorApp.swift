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
    private var appDelegateRetainer: LiteTextEditorApplication?
    private let recentDocumentStore = RecentDocumentStore()
    private weak var openRecentMenu: NSMenu?
    private var didConfirmWindowClose = false

    static func main() {
        let app = NSApplication.shared
        let delegate = LiteTextEditorApplication()

        app.delegate = delegate
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

        let hostingView = NSHostingView(
            rootView: EditorView()
                .frame(
                    minWidth: minimumWindowSize.width,
                    minHeight: minimumWindowSize.height,
                    alignment: .topLeading
                )
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Lite Text Editor"
        window.contentMinSize = minimumWindowSize
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumWindowSize)).size
        window.setFrameAutosaveName("LiteTextEditorMainWindow")
        window.setContentSize(clampedContentSize(for: window, minimumSize: minimumWindowSize))
        window.center()
        window.contentView = hostingView
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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

    @objc private func showLiteTextEditorHelp() {
        let alert = NSAlert()
        alert.messageText = "Lite Text Editor Help"
        alert.informativeText = "Use the Home menu or ribbon for core formatting, File for documents, and Tab to accept the next autocomplete word."
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

    @objc private func toggleBulletedList() {
        NotificationCenter.default.post(name: .liteTextEditorToggleBulletedList, object: nil)
    }

    @objc private func toggleNumberedList() {
        NotificationCenter.default.post(name: .liteTextEditorToggleNumberedList, object: nil)
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

    @objc private func setZoomPreset(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .liteTextEditorSetZoomPreset, object: sender.representedObject)
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
        fileMenu.addItem(NSMenuItem(title: "Print...", action: NSSelectorFromString("print:"), keyEquivalent: "p"))
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

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let homeMenuItem = NSMenuItem()
        let homeMenu = NSMenu(title: "Home")
        homeMenu.addItem(commandItem("Bold", action: #selector(toggleBold), key: "b"))
        homeMenu.addItem(commandItem("Italic", action: #selector(toggleItalic), key: "i"))
        homeMenu.addItem(commandItem("Underline", action: #selector(toggleUnderline), key: "u"))
        homeMenu.addItem(NSMenuItem.separator())
        homeMenu.addItem(commandItem("Bulleted List", action: #selector(toggleBulletedList), key: "8", modifiers: [.command, .shift]))
        homeMenu.addItem(commandItem("Numbered List", action: #selector(toggleNumberedList), key: "7", modifiers: [.command, .shift]))
        homeMenuItem.submenu = homeMenu
        mainMenu.addItem(homeMenuItem)

        let insertMenuItem = NSMenuItem()
        let insertMenu = NSMenu(title: "Insert")
        insertMenu.addItem(commandItem("Insert Autocomplete Word", action: #selector(acceptSuggestion), key: "\t", modifiers: []))
        insertMenuItem.submenu = insertMenu
        mainMenu.addItem(insertMenuItem)

        let layoutMenuItem = NSMenuItem()
        let layoutMenu = NSMenu(title: "Layout")
        layoutMenu.addItem(commandItem("Align Left", action: #selector(alignLeft), key: "l"))
        layoutMenu.addItem(commandItem("Center", action: #selector(alignCenter), key: "e"))
        layoutMenu.addItem(commandItem("Align Right", action: #selector(alignRight), key: "r"))
        layoutMenu.addItem(commandItem("Justify", action: #selector(justifyText), key: "j"))
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
        viewMenu.addItem(commandItem("Zoom In", action: #selector(zoomIn), key: "+"))
        viewMenu.addItem(commandItem("Zoom Out", action: #selector(zoomOut), key: "-"))
        viewMenu.addItem(commandItem("Actual Size", action: #selector(actualSize), key: "0"))
        viewMenu.addItem(commandItem("Fit Page", action: #selector(fitPageToScreen), key: "0", modifiers: [.command, .option]))
        viewMenu.addItem(NSMenuItem.separator())

        let zoomPresetMenuItem = NSMenuItem(title: "Zoom Size", action: nil, keyEquivalent: "")
        let zoomPresetMenu = NSMenu(title: "Zoom Size")
        DocumentZoomPreset.fixedPresets.forEach { preset in
            let item = NSMenuItem(title: preset.title, action: #selector(setZoomPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            zoomPresetMenu.addItem(item)
        }
        zoomPresetMenuItem.submenu = zoomPresetMenu
        viewMenu.addItem(zoomPresetMenuItem)
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
    static let liteTextEditorFlushAutosave = Notification.Name("liteTextEditorFlushAutosave")
    static let liteTextEditorExportPDF = Notification.Name("liteTextEditorExportPDF")
    static let liteTextEditorShowSettings = Notification.Name("liteTextEditorShowSettings")
    static let liteTextEditorBeginSpellingReview = Notification.Name("liteTextEditorBeginSpellingReview")
    static let liteTextEditorAcceptSuggestion = Notification.Name("liteTextEditorAcceptSuggestion")
    static let liteTextEditorToggleBold = Notification.Name("liteTextEditorToggleBold")
    static let liteTextEditorToggleItalic = Notification.Name("liteTextEditorToggleItalic")
    static let liteTextEditorToggleUnderline = Notification.Name("liteTextEditorToggleUnderline")
    static let liteTextEditorToggleBulletedList = Notification.Name("liteTextEditorToggleBulletedList")
    static let liteTextEditorToggleNumberedList = Notification.Name("liteTextEditorToggleNumberedList")
    static let liteTextEditorIncreaseIndent = Notification.Name("liteTextEditorIncreaseIndent")
    static let liteTextEditorDecreaseIndent = Notification.Name("liteTextEditorDecreaseIndent")
    static let liteTextEditorAlignLeft = Notification.Name("liteTextEditorAlignLeft")
    static let liteTextEditorAlignCenter = Notification.Name("liteTextEditorAlignCenter")
    static let liteTextEditorAlignRight = Notification.Name("liteTextEditorAlignRight")
    static let liteTextEditorJustifyText = Notification.Name("liteTextEditorJustifyText")
    static let liteTextEditorZoomIn = Notification.Name("liteTextEditorZoomIn")
    static let liteTextEditorZoomOut = Notification.Name("liteTextEditorZoomOut")
    static let liteTextEditorZoomFitPage = Notification.Name("liteTextEditorZoomFitPage")
    static let liteTextEditorZoomActualSize = Notification.Name("liteTextEditorZoomActualSize")
    static let liteTextEditorSetZoomPreset = Notification.Name("liteTextEditorSetZoomPreset")
    static let liteTextEditorRecentDocumentsChanged = Notification.Name("liteTextEditorRecentDocumentsChanged")
}
