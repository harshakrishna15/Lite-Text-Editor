import Foundation
import XCTest
@testable import LiteTextEditor

final class ComboBoxCompletionResolverTests: XCTestCase {
    private let resolver = ComboBoxCompletionResolver()

    func testTypingPrefixCompletesAndSelectsSuffix() {
        let decision = resolver.decision(
            typedText: "Hel",
            previousText: "",
            previousSelectionRange: NSRange(location: 0, length: 0),
            shouldSkipCompletion: false,
            items: ["Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "Helvetica")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 3, length: 6))
        XCTAssertTrue(decision.completed)
    }

    func testCompletionIsCaseInsensitive() {
        let decision = resolver.decision(
            typedText: "hel",
            previousText: "",
            previousSelectionRange: NSRange(location: 0, length: 0),
            shouldSkipCompletion: false,
            items: ["Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "Helvetica")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 3, length: 6))
        XCTAssertTrue(decision.completed)
    }

    func testCompletionIsDiacriticInsensitive() {
        let decision = resolver.decision(
            typedText: "Cafe",
            previousText: "",
            previousSelectionRange: NSRange(location: 0, length: 0),
            shouldSkipCompletion: false,
            items: ["Café Script", "System"]
        )

        XCTAssertEqual(decision.text, "Café Script")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 4, length: 7))
        XCTAssertTrue(decision.completed)
    }

    func testExactMatchDoesNotSelectAnEmptyCompletionSuffix() {
        let decision = resolver.decision(
            typedText: "System",
            previousText: "Syste",
            previousSelectionRange: NSRange(location: 5, length: 0),
            shouldSkipCompletion: false,
            items: ["System"]
        )

        XCTAssertEqual(decision.text, "System")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 6, length: 0))
        XCTAssertFalse(decision.completed)
    }

    func testCompletionOnlyMatchesFromTheBeginningOfTheItem() {
        let decision = resolver.decision(
            typedText: "vetica",
            previousText: "",
            previousSelectionRange: NSRange(location: 0, length: 0),
            shouldSkipCompletion: false,
            items: ["Helvetica"]
        )

        XCTAssertEqual(decision.text, "vetica")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 6, length: 0))
        XCTAssertFalse(decision.completed)
    }

    func testExplicitSkipPreventsCompletionEvenWhenTextWasSelected() {
        let decision = resolver.decision(
            typedText: "H",
            previousText: "System",
            previousSelectionRange: NSRange(location: 0, length: 6),
            shouldSkipCompletion: true,
            items: ["Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "H")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 1, length: 0))
        XCTAssertFalse(decision.completed)
    }

    func testEmptyInputDoesNotComplete() {
        let decision = resolver.decision(
            typedText: "",
            previousText: "System",
            previousSelectionRange: NSRange(location: 0, length: 6),
            shouldSkipCompletion: false,
            items: ["Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertFalse(decision.completed)
    }

    func testFirstMatchingItemWins() {
        let decision = resolver.decision(
            typedText: "He",
            previousText: "",
            previousSelectionRange: NSRange(location: 0, length: 0),
            shouldSkipCompletion: false,
            items: ["Helvetica Neue", "Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "Helvetica Neue")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 2, length: 12))
        XCTAssertTrue(decision.completed)
    }

    func testDeletingFinalCharacterDoesNotImmediatelyRecomplete() {
        let decision = resolver.decision(
            typedText: "Syste",
            previousText: "System",
            previousSelectionRange: NSRange(location: 6, length: 0),
            shouldSkipCompletion: true,
            items: ["System"]
        )

        XCTAssertEqual(decision.text, "Syste")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 5, length: 0))
        XCTAssertFalse(decision.completed)
    }

    func testShorterReplacementOfSelectedTextCanComplete() {
        let decision = resolver.decision(
            typedText: "H",
            previousText: "System",
            previousSelectionRange: NSRange(location: 0, length: 6),
            shouldSkipCompletion: false,
            items: ["Helvetica", "System"]
        )

        XCTAssertEqual(decision.text, "Helvetica")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 1, length: 8))
        XCTAssertTrue(decision.completed)
    }

    func testDeleteWithoutExplicitCommandStillDoesNotRecomplete() {
        let decision = resolver.decision(
            typedText: "Syste",
            previousText: "System",
            previousSelectionRange: NSRange(location: 6, length: 0),
            shouldSkipCompletion: false,
            items: ["System"]
        )

        XCTAssertEqual(decision.text, "Syste")
        XCTAssertEqual(decision.selectedRange, NSRange(location: 5, length: 0))
        XCTAssertFalse(decision.completed)
    }
}
