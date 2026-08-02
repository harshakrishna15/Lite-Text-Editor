import Foundation
import XCTest
@testable import LiteTextEditor

final class BundledLocalTextGeneratorTests: XCTestCase {
    func testDefaultModelLocationUsesApplicationSupportDownloadFolder() {
        let generator = BundledLocalTextGenerator(runtimeExecutableURL: nil)
        let downloadDirectoryPath = generator.modelDownloadDirectoryURL.path

        XCTAssertTrue(downloadDirectoryPath.contains("/Application Support/Lite Text Editor/Models/Files"))
        XCTAssertFalse(downloadDirectoryPath.contains("/Resources"))
        XCTAssertFalse(downloadDirectoryPath.contains(".app/Contents"))
    }

    func testDefaultModelDownloadSourceIsRemoteHTTPS() {
        let generator = BundledLocalTextGenerator(runtimeExecutableURL: nil)
        let sourceURL = generator.modelDownloadSourceURL

        XCTAssertEqual(sourceURL.scheme, "https")
        XCTAssertEqual(sourceURL.host, "huggingface.co")
        XCTAssertEqual(sourceURL.pathExtension.lowercased(), "gguf")
    }

    func testAppResourcesDoNotBundleModelWeights() throws {
        let resourcesURL = try packageRootURL()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("LiteTextEditor", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)

        let forbiddenExtensions: Set<String> = [
            "gguf",
            "ggml",
            "safetensors",
            "ckpt",
            "onnx",
            "pth",
            "pt",
            "bin"
        ]

        let bundledModelFiles = FileManager.default
            .enumerator(
                at: resourcesURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )?
            .compactMap { $0 as? URL }
            .filter { url in
                let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                return isRegularFile && forbiddenExtensions.contains(url.pathExtension.lowercased())
            } ?? []

        XCTAssertTrue(
            bundledModelFiles.isEmpty,
            "Model weights must be downloaded on demand, not bundled in app resources: \(bundledModelFiles.map(\.path))"
        )
    }

    func testRuntimeExecutableCandidatesIncludeSwiftPMAndLegacyResourceLayouts() {
        let resourceURL = URL(fileURLWithPath: "/tmp/LiteTextEditorResources", isDirectory: true)

        let candidates = BundledLocalTextGenerator.runtimeExecutableCandidateURLs(
            moduleResourceURL: resourceURL,
            mainResourceURL: nil
        )

        XCTAssertEqual(
            candidates,
            [
                resourceURL.appendingPathComponent("llama-server").standardizedFileURL,
                resourceURL
                    .appendingPathComponent("bin", isDirectory: true)
                    .appendingPathComponent("llama-server")
                    .standardizedFileURL
            ]
        )
    }

    func testRuntimeExecutableCandidatesDeduplicateSharedBundleURLs() {
        let resourceURL = URL(fileURLWithPath: "/tmp/LiteTextEditorResources", isDirectory: true)

        let candidates = BundledLocalTextGenerator.runtimeExecutableCandidateURLs(
            moduleResourceURL: resourceURL,
            mainResourceURL: resourceURL
        )

        XCTAssertEqual(candidates.count, 2)
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
        XCTAssertEqual(
            fixture.generator.modelDownloadDirectoryURL,
            fixture.modelFileURL.deletingLastPathComponent()
        )
    }

    func testLoadRequiresDownloadedModelFileAndBundledRuntime() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        do {
            try await fixture.generator.load()
            XCTFail("Expected load to fail when the GGUF file has not been downloaded.")
        } catch {
            XCTAssertFalse(fixture.generator.isLoaded)
        }

        try FileManager.default.createDirectory(
            at: fixture.modelFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: fixture.modelFileURL)

        do {
            try await fixture.generator.load()
            XCTFail("Expected load to fail when llama-server is not bundled.")
        } catch {
            XCTAssertFalse(fixture.generator.isLoaded)
        }
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

    func testCompletionUsesQwenChatEndpointAndParsesAssistantMessage() async throws {
        let fixture = try makeFixture(session: Self.stubbedSession())
        defer {
            StubURLProtocol.requestHandler = nil
            try? FileManager.default.removeItem(at: fixture.directory)
        }

        try FileManager.default.createDirectory(
            at: fixture.modelFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: fixture.modelFileURL)

        var completionRequest: URLRequest?
        StubURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/health":
                return Self.jsonResponse(
                    statusCode: 200,
                    body: #"{"status":"ok"}"#,
                    request: request
                )
            case "/v1/chat/completions":
                completionRequest = request
                return Self.jsonResponse(
                    statusCode: 200,
                    body: #"{"choices":[{"message":{"role":"assistant","content":"continues with context"}}]}"#,
                    request: request
                )
            default:
                return Self.jsonResponse(
                    statusCode: 404,
                    body: #"{"error":"unexpected endpoint"}"#,
                    request: request
                )
            }
        }

        try await fixture.generator.load()
        let completion = fixture.generator.completion(for: "Predict the next words.")

        XCTAssertEqual(completion, "continues with context")
        XCTAssertEqual(completionRequest?.url?.path, "/v1/chat/completions")

        let body = try XCTUnwrap(requestBodyData(from: completionRequest))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "test-qwen-autocomplete")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["max_tokens"] as? Int, 18)

        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["role"], "system")
        XCTAssertEqual(messages.last?["role"], "user")
        XCTAssertTrue(messages.last?["content"]?.contains("Predict the next words.") == true)
    }

    private func makeFixture(session: URLSession = .shared) throws -> (
        directory: URL,
        modelFileURL: URL,
        generator: BundledLocalTextGenerator
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteTextEditorTests-\(UUID().uuidString)", isDirectory: true)
        let modelFileURL = directory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("model.gguf")

        let generator = BundledLocalTextGenerator(
            model: "Test Qwen Model",
            modelAlias: "test-qwen-autocomplete",
            baseURL: URL(string: "http://127.0.0.1:1")!,
            modelFileURL: modelFileURL,
            downloadURL: URL(string: "https://example.invalid/model.gguf")!,
            runtimeExecutableURL: nil,
            timeout: 0.01,
            downloadTimeout: 0.01,
            retryDelay: 0,
            session: session
        )

        return (directory, modelFileURL, generator)
    }

    private func packageRootURL() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRootURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard FileManager.default.fileExists(
            atPath: packageRootURL
                .appendingPathComponent("Package.swift")
                .path
        ) else {
            throw NSError(
                domain: "LiteTextEditorTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate package root from \(testFileURL.path)."]
            )
        }

        return packageRootURL
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func jsonResponse(
        statusCode: Int,
        body: String,
        request: URLRequest
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        return (response, Data(body.utf8))
    }

    private func requestBodyData(from request: URLRequest?) -> Data? {
        guard let request else { return nil }
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 {
                break
            }

            data.append(buffer, count: count)
        }

        return data.isEmpty ? nil : data
    }
}

private final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
