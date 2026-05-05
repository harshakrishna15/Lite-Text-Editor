import XCTest
@testable import LiteTextEditor

final class LicenseAcknowledgementsTests: XCTestCase {
    func testAcknowledgementsIncludeBundledRuntimeAndModelLicenses() {
        let ids = LicenseAcknowledgements.all.map(\.id)

        XCTAssertEqual(ids, [
            "llama-cpp",
            "cpp-httplib",
            "nlohmann-json",
            "qwen2.5-0.5b-instruct-gguf"
        ])
    }

    func testLicenseTextResourcesAreBundled() {
        for acknowledgement in LicenseAcknowledgements.all {
            XCTAssertGreaterThan(acknowledgement.licenseText.count, 200, acknowledgement.name)
            XCTAssertFalse(acknowledgement.licenseText.contains("unavailable"), acknowledgement.name)
        }

        XCTAssertTrue(
            LicenseAcknowledgements.all
                .first { $0.id == "qwen2.5-0.5b-instruct-gguf" }?
                .licenseText
                .contains("Apache License") == true
        )
    }
}
