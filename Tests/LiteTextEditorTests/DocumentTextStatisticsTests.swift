import XCTest
@testable import LiteTextEditor

final class DocumentTextStatisticsTests: XCTestCase {
    func testEmptyTextKeepsMinimumPageCount() {
        let statistics = DocumentTextStatistics.make(from: "", pages: 0)

        XCTAssertEqual(statistics.words, 0)
        XCTAssertEqual(statistics.characters, 0)
        XCTAssertEqual(statistics.charactersNoSpaces, 0)
        XCTAssertEqual(statistics.sentences, 0)
        XCTAssertEqual(statistics.paragraphs, 0)
        XCTAssertEqual(statistics.lines, 0)
        XCTAssertEqual(statistics.pages, 1)
        XCTAssertEqual(statistics.readingTimeText, "0 min")
    }

    func testCountsWordsCharactersSentencesParagraphsAndLines() {
        let text = "Hello world.\n\nThis is a test."
        let statistics = DocumentTextStatistics.make(from: text, pages: 3)

        XCTAssertEqual(statistics.words, 6)
        XCTAssertEqual(statistics.characters, text.count)
        XCTAssertEqual(statistics.charactersNoSpaces, 23)
        XCTAssertEqual(statistics.sentences, 2)
        XCTAssertEqual(statistics.paragraphs, 2)
        XCTAssertEqual(statistics.lines, 3)
        XCTAssertEqual(statistics.pages, 3)
        XCTAssertEqual(statistics.readingTimeText, "<1 min")
    }

    func testReadingTimeRoundsUpAtReadingRate() {
        let text = Array(repeating: "word", count: 226).joined(separator: " ")
        let statistics = DocumentTextStatistics.make(from: text, pages: 1)

        XCTAssertEqual(statistics.words, 226)
        XCTAssertEqual(statistics.estimatedReadingMinutes, 2)
        XCTAssertEqual(statistics.readingTimeText, "2 min")
    }
}
