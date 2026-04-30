import AppKit
import XCTest
@testable import LiteTextEditor

final class DocumentOutlineExtractorTests: XCTestCase {
    func testExtractsTitleHeadingsAndSubheadings() {
        let document = NSMutableAttributedString(string: """
        Project Plan
        Overview
        First body paragraph.
        Details
        Detail body.
        Next Section
        Closing body.
        """)

        apply(font: .systemFont(ofSize: TextPreset.title.size, weight: TextPreset.title.weight), to: "Project Plan", in: document)
        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "Overview", in: document)
        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "Details", in: document)
        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "Next Section", in: document)

        let items = DocumentOutlineExtractor().makeOutlineItems(from: document)

        XCTAssertEqual(items.map(\.title), ["Project Plan", "Overview", "Details", "Next Section"])
        XCTAssertEqual(items.map(\.level), [0, 1, 2, 1])
        XCTAssertEqual(items.map(\.sectionNumber), ["", "1", "1.1", "2"])
        XCTAssertEqual(items[1].childCount, 1)
        XCTAssertEqual(items[1].displayTitle, "1 Overview")
        XCTAssertEqual(items[2].displayTitle, "1.1 Details")
        XCTAssertEqual(items[3].displayTitle, "2 Next Section")
    }

    func testIgnoresBodyTextBelowSubheadingSize() {
        let document = NSAttributedString(
            string: "Only body text",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )

        XCTAssertTrue(DocumentOutlineExtractor().makeOutlineItems(from: document).isEmpty)
    }

    private func apply(font: NSFont, to substring: String, in document: NSMutableAttributedString) {
        let range = (document.string as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, "Missing substring: \(substring)")
        document.addAttribute(.font, value: font, range: range)
    }
}
