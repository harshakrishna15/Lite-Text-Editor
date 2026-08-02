import AppKit
import XCTest
@testable import LiteTextEditor

final class EditorTypographyTests: XCTestCase {
    func testFontVariantsStayInCourierFamilyAndPreserveRequestedTraits() {
        let regular = EditorTypography.font(size: 13)
        let boldItalic = EditorTypography.font(size: 19, weight: .bold, italic: true)

        XCTAssertTrue(EditorTypography.isAllowedFont(regular))
        XCTAssertEqual(regular.pointSize, 13, accuracy: 0.001)
        XCTAssertFalse(regular.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertFalse(regular.fontDescriptor.symbolicTraits.contains(.italic))

        XCTAssertTrue(EditorTypography.isAllowedFont(boldItalic))
        XCTAssertEqual(boldItalic.pointSize, 19, accuracy: 0.001)
        XCTAssertTrue(boldItalic.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(boldItalic.fontDescriptor.symbolicTraits.contains(.italic))
    }

    func testAttributedStringNormalizationConvertsForeignFontsAndPreservesTraits() throws {
        let regularSource = NSFont.systemFont(ofSize: 13)
        let boldSource = NSFont.systemFont(ofSize: 18, weight: .bold)
        let boldItalicDescriptor = boldSource.fontDescriptor.withSymbolicTraits(
            boldSource.fontDescriptor.symbolicTraits.union(.italic)
        )
        let boldItalicSource = try XCTUnwrap(NSFont(descriptor: boldItalicDescriptor, size: 18))
        let source = NSMutableAttributedString(
            string: "Regular Bold Italic",
            attributes: [
                .font: regularSource,
                .foregroundColor: NSColor.systemRed
            ]
        )
        let emphasizedRange = (source.string as NSString).range(of: "Bold Italic")
        source.addAttributes(
            [
                .font: boldItalicSource,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            range: emphasizedRange
        )

        let normalized = EditorTypography.normalizedAttributedString(source)
        let regularFont = try XCTUnwrap(normalized.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let emphasizedFont = try XCTUnwrap(
            normalized.attribute(.font, at: emphasizedRange.location, effectiveRange: nil) as? NSFont
        )

        XCTAssertEqual(normalized.string, source.string)
        XCTAssertTrue(EditorTypography.isAllowedFont(regularFont))
        XCTAssertEqual(regularFont.pointSize, regularSource.pointSize, accuracy: 0.001)
        XCTAssertFalse(regularFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertFalse(regularFont.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertTrue(EditorTypography.isAllowedFont(emphasizedFont))
        XCTAssertEqual(emphasizedFont.pointSize, boldItalicSource.pointSize, accuracy: 0.001)
        XCTAssertTrue(emphasizedFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(emphasizedFont.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertTrue((normalized.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.isEqual(NSColor.systemRed) == true)
        XCTAssertEqual(
            normalized.attribute(.underlineStyle, at: emphasizedRange.location, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
    }

    func testTypingAttributeNormalizationUsesCourierAndRetainsOtherAttributes() throws {
        let sourceFont = NSFont.systemFont(ofSize: 16, weight: .bold)
        let normalized = EditorTypography.normalizedTypingAttributes([
            .font: sourceFont,
            .kern: CGFloat(1.25)
        ])
        let font = try XCTUnwrap(normalized[.font] as? NSFont)

        XCTAssertTrue(EditorTypography.isAllowedFont(font))
        XCTAssertEqual(font.pointSize, sourceFont.pointSize, accuracy: 0.001)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertEqual(normalized[.kern] as? CGFloat, 1.25)
        XCTAssertTrue((normalized[.foregroundColor] as? NSColor)?.isEqual(NSColor.black) == true)
    }
}
