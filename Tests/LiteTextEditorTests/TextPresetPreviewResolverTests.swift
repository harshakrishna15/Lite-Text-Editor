import AppKit
import XCTest
@testable import LiteTextEditor

final class TextPresetPreviewResolverTests: XCTestCase {
    private let resolver = TextPresetPreviewResolver()

    func testMenuPreviewSizesPreservePresetHierarchy() {
        XCTAssertGreaterThan(
            resolver.menuPreviewSize(for: .title),
            resolver.menuPreviewSize(for: .heading)
        )
        XCTAssertGreaterThan(
            resolver.menuPreviewSize(for: .heading),
            resolver.menuPreviewSize(for: .body)
        )
    }

    func testButtonPreviewSizesStayInsideToolbarFriendlyRange() {
        TextPreset.allCases.forEach { preset in
            XCTAssertGreaterThanOrEqual(resolver.buttonPreviewSize(for: preset), 13)
            XCTAssertLessThanOrEqual(resolver.buttonPreviewSize(for: preset), 16)
        }
    }

    func testMenuTitleUsesPresetNameAndPreviewFontSize() throws {
        let title = resolver.menuTitle(for: .heading, fontName: "System")
        let font = try XCTUnwrap(title.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(title.string, TextPreset.heading.title)
        XCTAssertEqual(font.pointSize, resolver.menuPreviewSize(for: .heading))
    }

    func testTitlePreviewUsesHeavierWeightThanBodyPreview() throws {
        let titleFont = try XCTUnwrap(
            resolver.menuTitle(for: .title, fontName: "System")
                .attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )
        let bodyFont = try XCTUnwrap(
            resolver.menuTitle(for: .body, fontName: "System")
                .attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )

        XCTAssertGreaterThan(titleFont.fontDescriptor.symbolicTraits.rawValue, 0)
        XCTAssertNotEqual(titleFont.fontName, bodyFont.fontName)
    }
}
