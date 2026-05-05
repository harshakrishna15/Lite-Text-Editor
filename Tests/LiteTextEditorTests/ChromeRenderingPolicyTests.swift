import XCTest
@testable import LiteTextEditor

final class ChromeRenderingPolicyTests: XCTestCase {
    func testRimRenderingUsesSingleFlatBorder() {
        XCTAssertLessThanOrEqual(ChromeRenderingPolicy.rimOverlayCount, 1)
        XCTAssertFalse(ChromeRenderingPolicy.usesMaskedLowerEdge)
    }

    func testLiquidGlassAndBackdropEffectsStayDisabled() {
        XCTAssertFalse(ChromeRenderingPolicy.usesNativeLiquidGlass)
        XCTAssertFalse(ChromeRenderingPolicy.usesBackdropBlur)
        XCTAssertFalse(ChromeRenderingPolicy.usesSystemMaterialBackgrounds)
        XCTAssertFalse(ChromeRenderingPolicy.usesNativeGlass(isLiveResizing: false))
        XCTAssertFalse(ChromeRenderingPolicy.usesNativeGlass(isLiveResizing: true))
    }

    func testFloatingPanelShadowBudgetKeepsLiveResizeVisibleAndSmall() {
        XCTAssertLessThanOrEqual(ChromeRenderingPolicy.floatingPanelShadowOpacity, 0.08)
        XCTAssertLessThanOrEqual(ChromeRenderingPolicy.floatingPanelShadowRadius, 4)
        XCTAssertLessThanOrEqual(ChromeRenderingPolicy.floatingPanelShadowYOffset, 2)
        XCTAssertGreaterThan(ChromeRenderingPolicy.liveResizeFloatingPanelShadowOpacity, 0)
        XCTAssertLessThanOrEqual(
            ChromeRenderingPolicy.liveResizeFloatingPanelShadowOpacity,
            ChromeRenderingPolicy.floatingPanelShadowOpacity
        )
        XCTAssertGreaterThan(ChromeRenderingPolicy.liveResizeFloatingPanelShadowRadius, 0)
        XCTAssertLessThanOrEqual(
            ChromeRenderingPolicy.liveResizeFloatingPanelShadowRadius,
            ChromeRenderingPolicy.floatingPanelShadowRadius
        )
        XCTAssertLessThanOrEqual(
            ChromeRenderingPolicy.liveResizeFloatingPanelShadowYOffset,
            ChromeRenderingPolicy.floatingPanelShadowYOffset
        )
    }
}
