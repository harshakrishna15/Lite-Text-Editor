import AppKit
import SwiftUI
import XCTest
@testable import LiteTextEditor

final class ToolbarControlLayoutTests: XCTestCase {
    func testToolbarDropdownsStayThinnerThanToolbarButtons() {
        XCTAssertEqual(ChromeStyle.toolbarDropdownControlHeight, 20)
        XCTAssertLessThan(ChromeStyle.toolbarDropdownControlHeight, ChromeStyle.toolbarControlHeight)
    }

    func testToolbarDropdownHeightMatchesNativeSmallControl() {
        let comboBox = NSComboBox()
        comboBox.controlSize = .small
        comboBox.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        comboBox.bezelStyle = .roundedBezel

        XCTAssertEqual(comboBox.intrinsicContentSize.height, ChromeStyle.toolbarDropdownControlHeight)
    }

    func testToolbarNativeDropdownViewsRejectCompressedHeights() {
        let comboBox = EditableComboBoxView()
        comboBox.setFrameSize(NSSize(width: 160, height: 12))
        comboBox.setBoundsSize(NSSize(width: 160, height: 12))

        XCTAssertEqual(comboBox.frame.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(comboBox.bounds.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(comboBox.intrinsicContentSize.height, ChromeStyle.toolbarDropdownControlHeight)
    }

    func testTitlebarIncludesEditableFontSizePicker() {
        let controller = EditorController()
        let host = NSHostingView(
            rootView: TitlebarEditorChromeView(editor: controller)
        )
        host.frame = NSRect(
            x: 0,
            y: 0,
            width: TitlebarEditorChromeLayout.width,
            height: TitlebarEditorChromeLayout.height
        )
        host.layoutSubtreeIfNeeded()

        let comboBox = firstSubview(of: EditableComboBoxView.self, in: host)
        XCTAssertNotNil(comboBox)
        XCTAssertEqual(comboBox?.stringValue, "12")
        XCTAssertEqual(comboBox?.frame.height, ChromeStyle.toolbarDropdownControlHeight)
    }
}

private func firstSubview<ViewType: NSView>(of type: ViewType.Type, in view: NSView) -> ViewType? {
    if let view = view as? ViewType {
        return view
    }

    for subview in view.subviews {
        if let match = firstSubview(of: type, in: subview) {
            return match
        }
    }

    return nil
}
