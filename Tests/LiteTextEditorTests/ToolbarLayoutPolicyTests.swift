import XCTest
@testable import LiteTextEditor

final class ToolbarLayoutPolicyTests: XCTestCase {
    func testToolbarBreakpointsStayOrderedAndCompactControlsShrink() {
        XCTAssertLessThan(ChromeStyle.toolbarCompactBreakpoint, ChromeStyle.toolbarModeInitialBreakpoint)
        XCTAssertLessThan(ChromeStyle.toolbarModeInitialBreakpoint, ChromeStyle.toolbarRegularBreakpoint)
        XCTAssertLessThanOrEqual(ChromeStyle.compactToolbarFontControlWidth, ChromeStyle.toolbarFontControlWidth)
        XCTAssertLessThanOrEqual(ChromeStyle.compactToolbarStyleControlWidth, ChromeStyle.toolbarStyleControlWidth)
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
