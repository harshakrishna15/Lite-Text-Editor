import XCTest
@testable import LiteTextEditor

final class RecentDocumentStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var store: RecentDocumentStore!

    override func setUp() {
        super.setUp()
        let suiteName = "LiteTextEditorTests.RecentDocumentStore.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = RecentDocumentStore(userDefaults: userDefaults, maximumCount: 3)
    }

    override func tearDown() {
        store.clear()
        store = nil
        userDefaults = nil
        super.tearDown()
    }

    func testNoteKeepsNewestFirstAndRemovesDuplicates() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.rtf")
        let secondURL = URL(fileURLWithPath: "/tmp/second.rtf")

        store.note(firstURL)
        store.note(secondURL)
        store.note(firstURL)

        XCTAssertEqual(store.load(), [firstURL.standardizedFileURL, secondURL.standardizedFileURL])
    }

    func testNoteTrimsToMaximumCount() {
        let urls = [
            URL(fileURLWithPath: "/tmp/one.rtf"),
            URL(fileURLWithPath: "/tmp/two.rtf"),
            URL(fileURLWithPath: "/tmp/three.rtf"),
            URL(fileURLWithPath: "/tmp/four.rtf")
        ]

        urls.forEach(store.note)

        XCTAssertEqual(
            store.load(),
            [
                urls[3].standardizedFileURL,
                urls[2].standardizedFileURL,
                urls[1].standardizedFileURL
            ]
        )
    }

    func testRemoveAndClearUpdateStoredDocuments() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.rtf")
        let secondURL = URL(fileURLWithPath: "/tmp/second.rtf")
        store.note(firstURL)
        store.note(secondURL)

        store.remove(firstURL)

        XCTAssertEqual(store.load(), [secondURL.standardizedFileURL])

        store.clear()

        XCTAssertTrue(store.load().isEmpty)
    }
}
