import AppKit
import XCTest
@testable import LiteTextEditor

final class ToolbarLayoutPolicyTests: XCTestCase {
    func testToolbarBreakpointsStayOrderedAndCompactControlsShrink() {
        XCTAssertLessThan(ChromeStyle.toolbarCompactBreakpoint, ChromeStyle.toolbarModeInitialBreakpoint)
        XCTAssertLessThan(ChromeStyle.toolbarModeInitialBreakpoint, ChromeStyle.toolbarRegularBreakpoint)
        XCTAssertLessThanOrEqual(ChromeStyle.compactToolbarFontControlWidth, ChromeStyle.toolbarFontControlWidth)
        XCTAssertLessThanOrEqual(ChromeStyle.compactToolbarStyleControlWidth, ChromeStyle.toolbarStyleControlWidth)
        XCTAssertLessThanOrEqual(ChromeStyle.compactToolbarHorizontalPadding, ChromeStyle.toolbarHorizontalPadding)
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
