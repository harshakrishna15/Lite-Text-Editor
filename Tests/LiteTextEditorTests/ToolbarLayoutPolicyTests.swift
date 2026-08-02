import AppKit
import SwiftUI
import XCTest
@testable import LiteTextEditor

final class ToolbarLayoutPolicyTests: XCTestCase {
    func testToolbarBreakpointsStayOrderedAndToolbarUsesOneTightSize() {
        XCTAssertLessThan(ChromeStyle.toolbarCompactBreakpoint, ChromeStyle.toolbarModeInitialBreakpoint)
        XCTAssertLessThan(ChromeStyle.toolbarModeInitialBreakpoint, ChromeStyle.toolbarRegularBreakpoint)
        XCTAssertEqual(ChromeStyle.compactToolbarFontControlWidth, ChromeStyle.toolbarFontControlWidth)
        XCTAssertEqual(ChromeStyle.compactToolbarStyleControlWidth, ChromeStyle.toolbarStyleControlWidth)
        XCTAssertEqual(ChromeStyle.compactToolbarHorizontalPadding, ChromeStyle.toolbarHorizontalPadding)
        XCTAssertEqual(ChromeStyle.compactToolbarHeight, ChromeStyle.regularToolbarHeight)
    }

    func testToolbarDropdownsStayThinnerThanToolbarButtons() {
        XCTAssertEqual(ChromeStyle.toolbarDropdownControlHeight, 20)
        XCTAssertLessThan(ChromeStyle.toolbarDropdownControlHeight, ChromeStyle.toolbarControlHeight)
    }

    func testToolbarDropdownHeightMatchesNativeSmallControls() {
        let comboBox = NSComboBox()
        comboBox.controlSize = .small
        comboBox.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        comboBox.bezelStyle = .roundedBezel

        let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popUpButton.controlSize = .small
        popUpButton.bezelStyle = .rounded
        popUpButton.isBordered = true
        popUpButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        popUpButton.addItem(withTitle: "Body")

        XCTAssertEqual(comboBox.intrinsicContentSize.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(popUpButton.fittingSize.height, ChromeStyle.toolbarDropdownControlHeight)
    }

    func testToolbarComboBoxUsesNativeHeightInsideTallerToolbarHost() {
        let view = EditableComboBox(
            text: .constant("System"),
            items: ["System", "Helvetica"],
            visibleItemCount: 2,
            onCommit: { _ in }
        )
        .toolbarDropdownControlFrame(width: 160)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 160, height: ChromeStyle.toolbarControlHeight)
        host.layoutSubtreeIfNeeded()

        let comboBox = firstSubview(of: NSComboBox.self, in: host)
        XCTAssertEqual(comboBox?.frame.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(host.fittingSize.height, ChromeStyle.toolbarControlHeight)
    }

    func testToolbarPresetPickerUsesNativeHeightInsideTallerToolbarHost() {
        let view = TextPresetPicker(selection: .constant(.body), fontName: "System") { _ in }
            .toolbarDropdownControlFrame(width: 160)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 160, height: ChromeStyle.toolbarControlHeight)
        host.layoutSubtreeIfNeeded()

        let button = firstSubview(of: ToolbarPopUpButton.self, in: host)
        XCTAssertEqual(button?.frame.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(host.fittingSize.height, ChromeStyle.toolbarControlHeight)
    }

    func testToolbarDropdownFrameKeepsNativeHeightAcrossCompactWidths() {
        let widths = [
            ChromeStyle.toolbarFontControlWidth,
            ChromeStyle.compactToolbarFontControlWidth,
            ChromeStyle.toolbarStyleControlWidth,
            ChromeStyle.compactToolbarStyleControlWidth
        ]

        for width in widths {
            let view = EditableComboBox(
                text: .constant("System"),
                items: ["System", "Helvetica"],
                visibleItemCount: 2,
                onCommit: { _ in }
            )
            .toolbarDropdownControlFrame(width: width)

            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: width, height: ChromeStyle.toolbarControlHeight)
            host.layoutSubtreeIfNeeded()

            let comboBox = firstSubview(of: NSComboBox.self, in: host)
            XCTAssertEqual(comboBox?.frame.height, ChromeStyle.toolbarDropdownControlHeight)
            XCTAssertEqual(host.fittingSize.height, ChromeStyle.toolbarControlHeight)
        }
    }

    func testToolbarNativeDropdownViewsRejectCompressedHeights() {
        let comboBox = EditableComboBoxView()
        comboBox.setFrameSize(NSSize(width: 160, height: 12))

        let popUpButton = ToolbarPopUpButton()
        popUpButton.setFrameSize(NSSize(width: 160, height: 12))
        popUpButton.setBoundsSize(NSSize(width: 160, height: 12))
        comboBox.setBoundsSize(NSSize(width: 160, height: 12))

        XCTAssertEqual(comboBox.frame.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(popUpButton.frame.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(comboBox.bounds.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(popUpButton.bounds.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(comboBox.intrinsicContentSize.height, ChromeStyle.toolbarDropdownControlHeight)
        XCTAssertEqual(popUpButton.intrinsicContentSize.height, ChromeStyle.toolbarDropdownControlHeight)
    }

    func testInitialModeUsesMiddleBreakpoint() {
        XCTAssertFalse(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: ChromeStyle.toolbarModeInitialBreakpoint + 1,
                isCurrentlyCompact: false,
                animated: false
            )
        )

        XCTAssertTrue(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: ChromeStyle.toolbarModeInitialBreakpoint - 1,
                isCurrentlyCompact: false,
                animated: false
            )
        )
    }

    func testAnimatedModeUsesHysteresisToAvoidFlicker() {
        let widthBetweenBreakpoints = (
            ChromeStyle.toolbarCompactBreakpoint + ChromeStyle.toolbarRegularBreakpoint
        ) / 2

        XCTAssertTrue(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: widthBetweenBreakpoints,
                isCurrentlyCompact: true,
                animated: true
            )
        )

        XCTAssertFalse(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: widthBetweenBreakpoints,
                isCurrentlyCompact: false,
                animated: true
            )
        )
    }

    func testInvalidWidthKeepsCurrentMode() {
        XCTAssertTrue(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: 0,
                isCurrentlyCompact: true,
                animated: true
            )
        )

        XCTAssertFalse(
            ToolbarLayoutPolicy.shouldUseCompactToolbar(
                width: 0,
                isCurrentlyCompact: false,
                animated: true
            )
        )
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
