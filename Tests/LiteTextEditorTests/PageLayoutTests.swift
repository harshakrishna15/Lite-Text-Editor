import XCTest
@testable import LiteTextEditor

final class PageLayoutTests: XCTestCase {
    func testPageCountUsesVisualPageGapAwareHeight() {
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: 0), 1)
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: AutocompleteTextView.pageContentHeight), 1)
        XCTAssertEqual(AutocompleteTextView.pageCount(forVisualContentHeight: AutocompleteTextView.pageContentHeight + 1), 2)
    }

    func testVisualContentConversionAccountsForPageGapAfterFirstPage() {
        let secondPageContentY = AutocompleteTextView.pageContentHeight + 24
        let expectedVisualY = AutocompleteTextView.pageHeight + AutocompleteTextView.pageGap + 24

        XCTAssertEqual(AutocompleteTextView.visualContentY(forContentY: secondPageContentY), expectedVisualY)
        XCTAssertEqual(AutocompleteTextView.contentY(fromPotentialVisualY: expectedVisualY), secondPageContentY)
    }

    func testPageStackHeightIncludesGapsBetweenPagesOnly() {
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 0), AutocompleteTextView.pageHeight)
        XCTAssertEqual(AutocompleteTextView.pageStackHeight(forPageCount: 1), AutocompleteTextView.pageHeight)
        XCTAssertEqual(
            AutocompleteTextView.pageStackHeight(forPageCount: 3),
            (AutocompleteTextView.pageHeight * 3) + (AutocompleteTextView.pageGap * 2)
        )
    }
}
