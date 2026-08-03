import XCTest
@testable import LiteTextEditor

final class DocumentTextStatisticsTests: XCTestCase {
    func testEmptyTextKeepsMinimumPageCount() {
        let statistics = DocumentTextStatistics.make(from: "", pages: 0)

        XCTAssertEqual(statistics.words, 0)
        XCTAssertEqual(statistics.pages, 1)
    }

    func testCountsWordsAndUsesRenderedPageCount() {
        let text = "Hello world.\n\nThis is a test."
        let statistics = DocumentTextStatistics.make(from: text, pages: 3)

        XCTAssertEqual(statistics.words, 6)
        XCTAssertEqual(statistics.pages, 3)
    }
}
