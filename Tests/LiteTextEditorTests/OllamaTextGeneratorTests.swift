import Foundation
import XCTest
@testable import LiteTextEditor

final class OllamaTextGeneratorTests: XCTestCase {
    func testDownloadProgressFormatsPercentageAndEstimatedTime() {
        let progress = LocalModelDownloadProgress(
            bytesDownloaded: 42,
            totalBytes: 100,
            estimatedSecondsRemaining: 75
        )

        XCTAssertEqual(progress.fractionCompleted, 0.42)
        XCTAssertEqual(progress.percentageText, "42%")
        XCTAssertEqual(progress.statusText, "Downloading... 42% - about 2m left")
        XCTAssertEqual(
            LocalModelState.downloading(modelName: "test", progress: progress).statusText,
            "Downloading... 42% - about 2m left"
        )
    }

    func testDownloadedStateUsesModelFileWithoutRuntime() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let initialDownloadedState = try await fixture.generator.isDownloaded()
        XCTAssertFalse(initialDownloadedState)

        try FileManager.default.createDirectory(
            at: fixture.modelFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: fixture.modelFileURL)

        let downloadedState = try await fixture.generator.isDownloaded()
        XCTAssertTrue(downloadedState)
        XCTAssertFalse(fixture.generator.isLoaded)
    }

    func testUninstallRemovesModelFileWithoutRuntime() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try FileManager.default.createDirectory(
            at: fixture.modelFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: fixture.modelFileURL)

        try await fixture.generator.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelFileURL.path))
        let downloadedState = try await fixture.generator.isDownloaded()
        XCTAssertFalse(downloadedState)
        XCTAssertFalse(fixture.generator.isLoaded)
    }

    private func makeFixture() throws -> (
        directory: URL,
        modelFileURL: URL,
        generator: OllamaTextGenerator
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteTextEditorTests-\(UUID().uuidString)", isDirectory: true)
        let modelFileURL = directory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("model.gguf")

        let generator = OllamaTextGenerator(
            model: "test-autocomplete-model:latest",
            baseURL: URL(string: "http://127.0.0.1:1")!,
            modelsDirectory: directory.appendingPathComponent("Ollama", isDirectory: true),
            modelFileURL: modelFileURL,
            downloadURL: URL(string: "https://example.invalid/model.gguf")!,
            ollamaExecutableURL: nil,
            timeout: 0.01,
            downloadTimeout: 0.01,
            retryDelay: 0
        )

        return (directory, modelFileURL, generator)
    }
}
