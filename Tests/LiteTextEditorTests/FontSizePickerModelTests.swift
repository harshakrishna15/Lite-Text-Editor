import XCTest
@testable import LiteTextEditor

final class FontSizePickerModelTests: XCTestCase {
    func testParsesNumericAndPointSizeText() {
        XCTAssertEqual(FontSizePickerModel.size(from: "14"), 14)
        XCTAssertEqual(FontSizePickerModel.size(from: " 18.5 pt "), 18.5)
        XCTAssertNil(FontSizePickerModel.size(from: "large"))
    }

    func testClampsEnteredAndSteppedSizesToSupportedRange() {
        XCTAssertEqual(FontSizePickerModel.size(from: "0"), FontSizePickerModel.minimumSize)
        XCTAssertEqual(FontSizePickerModel.size(from: "900"), FontSizePickerModel.maximumSize)
        XCTAssertEqual(
            FontSizePickerModel.steppedSize(from: FontSizePickerModel.minimumSize, direction: -1),
            FontSizePickerModel.minimumSize
        )
        XCTAssertEqual(
            FontSizePickerModel.steppedSize(from: FontSizePickerModel.maximumSize, direction: 1),
            FontSizePickerModel.maximumSize
        )
    }

    func testDisplaysWholeAndFractionalPointSizesCompactly() {
        XCTAssertEqual(FontSizePickerModel.displayText(for: 12), "12")
        XCTAssertEqual(FontSizePickerModel.displayText(for: 12.5), "12.5")
        XCTAssertTrue(FontSizePickerModel.commonSizeTitles.contains("14"))
    }
}
