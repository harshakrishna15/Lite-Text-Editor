import AppKit
import XCTest
@testable import LiteTextEditor

final class FontPreviewResolverTests: XCTestCase {
    private let resolver = FontPreviewResolver()

    func testSystemFontPreviewUsesSystemFont() {
        let font = resolver.font(for: "System", size: 13)

        XCTAssertEqual(font.pointSize, 13)
        XCTAssertEqual(font.familyName, NSFont.systemFont(ofSize: 13).familyName)
    }

    func testKnownFontFamilyUsesThatFamilyWhenAvailable() throws {
        try XCTSkipUnless(NSFontManager.shared.availableFontFamilies.contains("Helvetica"))

        let font = resolver.font(for: "Helvetica", size: 13)

        XCTAssertEqual(font.familyName, "Helvetica")
        XCTAssertEqual(font.pointSize, 13)
    }

    func testUnknownFontFallsBackToSystemFont() {
        let font = resolver.font(for: "Definitely Missing Font Family", size: 13)

        XCTAssertEqual(font.familyName, NSFont.systemFont(ofSize: 13).familyName)
        XCTAssertEqual(font.pointSize, 13)
    }

    func testAttributedTitleUsesPreviewFontAndPreservesDisplayName() throws {
        let title = resolver.attributedTitle(for: "System", size: 13)
        let font = try XCTUnwrap(title.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(title.string, "System")
        XCTAssertEqual(font.familyName, NSFont.systemFont(ofSize: 13).familyName)
        XCTAssertEqual(font.pointSize, 13)
    }
}
