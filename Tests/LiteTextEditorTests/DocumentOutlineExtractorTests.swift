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
        XCTAssertEqual(items[1].headingWordCount, 1)
        XCTAssertGreaterThan(items[1].sectionLength, items[1].headingLength)
        XCTAssertGreaterThan(items[1].sectionEndLocation, items[1].location)
    }

    func testIgnoresBodyTextBelowSubheadingSize() {
        let document = NSAttributedString(
            string: "Only body text",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )

        XCTAssertTrue(DocumentOutlineExtractor().makeOutlineItems(from: document).isEmpty)
    }

    func testStructureMetadataSummarizesDocumentSections() {
        let document = NSMutableAttributedString(string: """
        Release Notes
        Added
        The app can save files.
        Fixed
        Zoom remains stable.
        Polish
        Menus look better.
        """)

        apply(font: .systemFont(ofSize: TextPreset.title.size, weight: TextPreset.title.weight), to: "Release Notes", in: document)
        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "Added", in: document)
        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "Fixed", in: document)
        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "Polish", in: document)

        let snapshot = DocumentOutlineExtractor().makeStructureSnapshot(from: document)

        XCTAssertEqual(snapshot.metadata.title, "Release Notes")
        XCTAssertEqual(snapshot.metadata.titleCount, 1)
        XCTAssertEqual(snapshot.metadata.sectionCount, 2)
        XCTAssertEqual(snapshot.metadata.subsectionCount, 1)
        XCTAssertEqual(snapshot.metadata.deepestLevel, 2)
        XCTAssertTrue(snapshot.metadata.hasStructure)
        XCTAssertEqual(snapshot.items.map(\.sectionNumber), ["", "1", "2", "2.1"])
    }

    func testSubheadingBeforeHeadingGetsReadableParentNumber() {
        let document = NSMutableAttributedString(string: """
        Orphan Subheading
        Body.
        """)

        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "Orphan Subheading", in: document)

        let items = DocumentOutlineExtractor().makeOutlineItems(from: document)

        XCTAssertEqual(items.map(\.sectionNumber), ["1.1"])
    }

    func testChildCountsStopAtSameLevelSiblingAndIncludeNestedChildren() {
        let document = NSMutableAttributedString(string: """
        First Section
        First Child
        Second Child
        Second Section
        Third Child
        """)

        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "First Section", in: document)
        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "First Child", in: document)
        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "Second Child", in: document)
        apply(font: .systemFont(ofSize: TextPreset.heading.size, weight: TextPreset.heading.weight), to: "Second Section", in: document)
        apply(font: .systemFont(ofSize: TextPreset.subheading.size, weight: TextPreset.subheading.weight), to: "Third Child", in: document)

        let items = DocumentOutlineExtractor().makeOutlineItems(from: document)

        XCTAssertEqual(items.map(\.title), ["First Section", "First Child", "Second Child", "Second Section", "Third Child"])
        XCTAssertEqual(items.map(\.childCount), [2, 0, 0, 1, 0])
    }

    private func apply(font: NSFont, to substring: String, in document: NSMutableAttributedString) {
        let range = (document.string as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, "Missing substring: \(substring)")
        document.addAttribute(.font, value: font, range: range)
    }
}
