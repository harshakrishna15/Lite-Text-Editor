import Dispatch
import Foundation
import CryptoKit

final class OllamaTextGenerator: LocalModelTextGenerating {
    private enum Availability {
        case unknown
        case available
        case unavailable(Date)
    }

    private struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
        let options: GenerateOptions
        let keepAlive: String?

        enum CodingKeys: String, CodingKey {
            case model
            case prompt
            case stream
            case options
            case keepAlive = "keep_alive"
        }
    }

    private struct GenerateOptions: Encodable {
        let temperature: Double
        let topP: Double
        let numPredict: Int
        let repeatPenalty: Double
        let stop: [String]

        enum CodingKeys: String, CodingKey {
            case temperature
            case topP = "top_p"
            case numPredict = "num_predict"
            case repeatPenalty = "repeat_penalty"
            case stop
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String?
        let error: String?
    }

    private struct CreateRequest: Encodable {
        let model: String
        let files: [String: String]
        let parameters: CreateParameters
        let stream: Bool
    }

    private struct CreateParameters: Encodable {
        let numCtx: Int

        enum CodingKeys: String, CodingKey {
            case numCtx = "num_ctx"
        }
    }

    private struct CreateResponse: Decodable {
        let status: String?
        let error: String?
    }

    private struct DeleteRequest: Encodable {
        let model: String
    }

    private struct RunningModelsResponse: Decodable {
        let models: [RunningModel]
    }

    private struct RunningModel: Decodable {
        let name: String?
        let model: String?
    }

    private struct InstalledModelsResponse: Decodable {
        let models: [InstalledModel]
    }

    private struct InstalledModel: Decodable {
        let name: String?
        let model: String?
    }

    private enum GeneratorError: Error {
        case missingRuntime
        case missingModelFile
        case unavailable
        case unexpectedStatus
    }

    private static let defaultPort = 11435
    private static let defaultModelDownloadURLString = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/df5bf01389a39c743ab467d734bf501681e041c5/qwen2.5-0.5b-instruct-q4_k_m.gguf"
    private static let defaultModelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

    private let model: String
    private let baseURL: URL
    private let modelsDirectory: URL
    private let modelFileURL: URL
    private let downloadURL: URL
    private let ollamaExecutableURL: URL?
    private let timeout: TimeInterval
    private let downloadTimeout: TimeInterval
    private let retryDelay: TimeInterval
    private let session: URLSession
    private let stateLock = NSLock()
    private var availability: Availability = .unknown
    private var serverProcess: Process?

    var isLoaded: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        if case .available = availability {
            return true
        }

        return false
    }

    var modelName: String {
        model
    }

    var modelDownloadDirectoryURL: URL {
        modelFileURL.deletingLastPathComponent()
    }

    init(
        model: String = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_OLLAMA_MODEL"] ?? "lite-text-editor-qwen-document-autocomplete:latest",
        baseURL: URL = OllamaTextGenerator.defaultBaseURL(),
        modelsDirectory: URL = OllamaTextGenerator.defaultModelsDirectory(),
        modelFileURL: URL = OllamaTextGenerator.defaultModelFileURL(),
        downloadURL: URL = OllamaTextGenerator.defaultDownloadURL(),
        ollamaExecutableURL: URL? = OllamaTextGenerator.defaultOllamaExecutableURL(),
        timeout: TimeInterval = 1.5,
        downloadTimeout: TimeInterval = 600,
        retryDelay: TimeInterval = 20,
        session: URLSession = .shared
    ) {
        self.model = model
        self.baseURL = baseURL
        self.modelsDirectory = modelsDirectory
        self.modelFileURL = modelFileURL
        self.downloadURL = downloadURL
        self.ollamaExecutableURL = ollamaExecutableURL
        self.timeout = timeout
        self.downloadTimeout = downloadTimeout
        self.retryDelay = retryDelay
        self.session = session
    }

    func load() async throws {
        if isLoaded { return }
        guard hasDownloadedModelFile() else { throw GeneratorError.missingModelFile }
        guard shouldProbeAvailability() else { throw GeneratorError.unavailable }

        do {
            try await ensureServerRunning()
            try await ensureRuntimeModelAvailable()
            try Task.checkCancellation()
            try await warmUpModel()
            try Task.checkCancellation()

            var request = URLRequest(url: endpoint("api", "ps"))
            request.timeoutInterval = timeout

            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.isSuccessful == true else {
                markUnavailable()
                throw GeneratorError.unexpectedStatus
            }

            let runningModels = try JSONDecoder().decode(RunningModelsResponse.self, from: data)
            guard runningModels.models.contains(where: matchesConfiguredModel) else {
                markUnavailable()
                throw GeneratorError.unavailable
            }

            markAvailable()
        } catch {
            markUnavailable()
            throw error
        }
    }

    func isDownloaded() async throws -> Bool {
        hasDownloadedModelFile()
    }

    func download() async throws {
        try await download(progressHandler: nil)
    }

    func download(progressHandler: LocalModelDownloadProgressHandler?) async throws {
        if !hasDownloadedModelFile() {
            try await downloadModelFile(progressHandler: progressHandler)
        }

        markUnknown()
        try? await load()
    }

    func uninstall() async throws {
        do {
            try await deleteRuntimeModelIfPossible()
            try removeDownloadedModelFile()
            markUnavailable()
        } catch {
            markUnavailable()
            throw error
        }
    }

    private func downloadModelFile(progressHandler: LocalModelDownloadProgressHandler?) async throws {
        try FileManager.default.createDirectory(
            at: modelFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"
        request.timeoutInterval = downloadTimeout

        let partialURL = partialModelFileURL
        do {
            let downloader = ModelFileDownloader(
                destinationURL: partialURL,
                progressHandler: progressHandler
            )
            let response = try await downloader.download(request: request)
            guard (response as? HTTPURLResponse)?.isSuccessful == true else {
                throw GeneratorError.unexpectedStatus
            }

            try Task.checkCancellation()
            guard modelFileSize(at: partialURL) > 0 else {
                try? removeFileIfPresent(at: partialURL)
                throw GeneratorError.unexpectedStatus
            }

            try removeFileIfPresent(at: modelFileURL)
            try FileManager.default.moveItem(at: partialURL, to: modelFileURL)
        } catch {
            try? removeFileIfPresent(at: partialURL)
            throw error
        }
    }

    private var partialModelFileURL: URL {
        modelFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(modelFileURL.lastPathComponent).download")
    }

    private func removeDownloadedModelFile() throws {
        try removeFileIfPresent(at: partialModelFileURL)
        try removeFileIfPresent(at: modelFileURL)
    }

    private func removeFileIfPresent(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func hasDownloadedModelFile() -> Bool {
        FileManager.default.fileExists(atPath: modelFileURL.path)
            && modelFileSize(at: modelFileURL) > 0
    }

    private func modelFileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private func ensureRuntimeModelAvailable() async throws {
        if try await isRuntimeModelInstalled() {
            return
        }

        try await createRuntimeModel()
    }

    private func isRuntimeModelInstalled() async throws -> Bool {
        var request = URLRequest(url: endpoint("api", "tags"))
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.isSuccessful == true else {
            throw GeneratorError.unexpectedStatus
        }

        let installedModels = try JSONDecoder().decode(InstalledModelsResponse.self, from: data)
        return installedModels.models.contains(where: matchesConfiguredModel)
    }

    private func createRuntimeModel() async throws {
        let digest = try sha256Digest(for: modelFileURL)
        try await ensureRuntimeBlobExists(digest: digest)

        let createRequest = CreateRequest(
            model: model,
            files: [modelFileURL.lastPathComponent: "sha256:\(digest)"],
            parameters: CreateParameters(numCtx: 2048),
            stream: false
        )
        guard let httpBody = try? JSONEncoder().encode(createRequest) else {
            throw GeneratorError.unexpectedStatus
        }

        var request = URLRequest(url: endpoint("api", "create"))
        request.httpMethod = "POST"
        request.timeoutInterval = min(downloadTimeout, 120)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.isSuccessful == true else {
            throw GeneratorError.unexpectedStatus
        }

        if let decoded = try? JSONDecoder().decode(CreateResponse.self, from: data),
           decoded.error != nil {
            throw GeneratorError.unavailable
        }
    }

    private func ensureRuntimeBlobExists(digest: String) async throws {
        let blobURL = endpoint("api", "blobs", "sha256:\(digest)")

        var headRequest = URLRequest(url: blobURL)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = timeout

        if let (_, response) = try? await session.data(for: headRequest),
           (response as? HTTPURLResponse)?.isSuccessful == true {
            return
        }

        var uploadRequest = URLRequest(url: blobURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.timeoutInterval = min(downloadTimeout, 300)

        let (_, response) = try await session.upload(for: uploadRequest, fromFile: modelFileURL)
        guard (response as? HTTPURLResponse)?.isSuccessful == true else {
            throw GeneratorError.unexpectedStatus
        }
    }

    private func sha256Digest(for url: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try fileHandle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func deleteRuntimeModelIfPossible() async throws {
        guard await ensureServerRunningIfPossible() else { return }
        guard (try? await isRuntimeModelInstalled()) == true else { return }

        let deleteRequest = DeleteRequest(model: model)
        guard let httpBody = try? JSONEncoder().encode(deleteRequest) else {
            throw GeneratorError.unexpectedStatus
        }

        var request = URLRequest(url: endpoint("api", "delete"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeneratorError.unexpectedStatus
        }

        guard httpResponse.statusCode != 404 else { return }
        guard httpResponse.isSuccessful else {
            throw GeneratorError.unexpectedStatus
        }
    }

    func completion(for prompt: String) -> String? {
        guard isLoaded else { return nil }

        let body = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: GenerateOptions(
                temperature: 0.25,
                topP: 0.9,
                numPredict: 18,
                repeatPenalty: 1.18,
                stop: ["\n", "[CURSOR]", "Completion:"]
            ),
            keepAlive: "30m"
        )

        guard let httpBody = try? JSONEncoder().encode(body) else { return nil }

        var request = URLRequest(url: endpoint("api", "generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        let semaphore = DispatchSemaphore(value: 0)
        var completion: String?

        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard error == nil else {
                self.markUnavailable()
                return
            }
            guard (response as? HTTPURLResponse)?.isSuccessful == true else {
                self.markUnavailable()
                return
            }
            guard let data else { return }
            guard let decoded = try? JSONDecoder().decode(GenerateResponse.self, from: data) else { return }
            guard decoded.error == nil else {
                self.markUnavailable()
                return
            }

            completion = decoded.response?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        task.resume()

        if semaphore.wait(timeout: .now() + timeout + 0.5) == .timedOut {
            task.cancel()
            return nil
        }

        return completion?.isEmpty == true ? nil : completion
    }

    private func endpoint(_ pathComponents: String...) -> URL {
        pathComponents.reduce(baseURL) { url, component in
            url.appendingPathComponent(component)
        }
    }

    private static func defaultBaseURL() -> URL {
        if let rawURL = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_OLLAMA_BASE_URL"],
           let url = URL(string: rawURL) {
            return url
        }

        return URL(string: "http://127.0.0.1:\(defaultPort)")!
    }

    private static func defaultModelsDirectory() -> URL {
        applicationSupportDirectory()
            .appendingPathComponent("Lite Text Editor", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Ollama", isDirectory: true)
    }

    private static func defaultModelFileURL() -> URL {
        applicationSupportDirectory()
            .appendingPathComponent("Lite Text Editor", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Files", isDirectory: true)
            .appendingPathComponent(defaultModelFileName)
    }

    private static func defaultDownloadURL() -> URL {
        if let rawURL = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_MODEL_URL"],
           let url = URL(string: rawURL) {
            return url
        }

        return URL(string: defaultModelDownloadURLString)!
    }

    private static func applicationSupportDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return applicationSupport
    }

    private static func defaultOllamaExecutableURL() -> URL? {
        if let rawPath = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_OLLAMA_PATH"],
           FileManager.default.isExecutableFile(atPath: rawPath) {
            return URL(fileURLWithPath: rawPath)
        }

        let candidatePaths = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/usr/bin/ollama"
        ]

        return candidatePaths
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map(URL.init(fileURLWithPath:))
    }

    private func ensureServerRunning() async throws {
        if await isServerReachable() {
            return
        }

        try startAppManagedServer()

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if await isServerReachable() {
                return
            }

            try await Task.sleep(nanoseconds: 150_000_000)
        }

        throw GeneratorError.unavailable
    }

    private func ensureServerRunningIfPossible() async -> Bool {
        do {
            try await ensureServerRunning()
            return true
        } catch {
            return false
        }
    }

    private func isServerReachable() async -> Bool {
        var request = URLRequest(url: endpoint("api", "tags"))
        request.timeoutInterval = 0.35

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.isSuccessful == true
        } catch {
            return false
        }
    }

    private func startAppManagedServer() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        if serverProcess?.isRunning == true {
            return
        }

        guard let ollamaExecutableURL else {
            throw GeneratorError.missingRuntime
        }

        try FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = ollamaExecutableURL
        process.arguments = ["serve"]

        var environment = ProcessInfo.processInfo.environment
        environment["OLLAMA_HOST"] = ollamaHost
        environment["OLLAMA_MODELS"] = modelsDirectory.path
        process.environment = environment

        if let nullHandle = FileHandle(forWritingAtPath: "/dev/null") {
            process.standardOutput = nullHandle
            process.standardError = nullHandle
        }

        try process.run()
        serverProcess = process
    }

    private var ollamaHost: String {
        guard let host = baseURL.host else {
            return "127.0.0.1:\(Self.defaultPort)"
        }

        if let port = baseURL.port {
            return "\(host):\(port)"
        }

        return host
    }

    private func warmUpModel() async throws {
        let body = GenerateRequest(
            model: model,
            prompt: " ",
            stream: false,
            options: GenerateOptions(
                temperature: 0,
                topP: 0.1,
                numPredict: 1,
                repeatPenalty: 1,
                stop: ["\n"]
            ),
            keepAlive: "30m"
        )

        guard let httpBody = try? JSONEncoder().encode(body) else {
            throw GeneratorError.unexpectedStatus
        }

        var request = URLRequest(url: endpoint("api", "generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = min(downloadTimeout, 60)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.isSuccessful == true else {
            markUnavailable()
            throw GeneratorError.unexpectedStatus
        }
    }

    private func matchesConfiguredModel(_ runningModel: RunningModel) -> Bool {
        [runningModel.name, runningModel.model]
            .compactMap { $0 }
            .contains(model)
    }

    private func matchesConfiguredModel(_ installedModel: InstalledModel) -> Bool {
        [installedModel.name, installedModel.model]
            .compactMap { $0 }
            .contains(model)
    }

    private func shouldProbeAvailability() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        switch availability {
        case .available, .unknown:
            return true
        case .unavailable(let lastAttempt):
            return Date().timeIntervalSince(lastAttempt) >= retryDelay
        }
    }

    private func markAvailable() {
        stateLock.lock()
        availability = .available
        stateLock.unlock()
    }

    private func markUnavailable() {
        stateLock.lock()
        availability = .unavailable(Date())
        stateLock.unlock()
    }

    private func markUnknown() {
        stateLock.lock()
        availability = .unknown
        stateLock.unlock()
    }
}

private final class ModelFileDownloader: NSObject, URLSessionDownloadDelegate {
    private let destinationURL: URL
    private let progressHandler: LocalModelDownloadProgressHandler?
    private let startedAt = Date()
    private let reportInterval: TimeInterval = 0.25
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URLResponse, Error>?
    private var downloadTask: URLSessionDownloadTask?
    private var lastReportDate = Date.distantPast

    init(
        destinationURL: URL,
        progressHandler: LocalModelDownloadProgressHandler?
    ) {
        self.destinationURL = destinationURL
        self.progressHandler = progressHandler
    }

    func download(request: URLRequest) async throws -> URLResponse {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        configuration.timeoutIntervalForResource = request.timeoutInterval

        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        defer {
            session.finishTasksAndInvalidate()
        }

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    lock.lock()
                    self.continuation = continuation
                    lock.unlock()

                    let task = session.downloadTask(with: request)

                    lock.lock()
                    self.downloadTask = task
                    lock.unlock()

                    task.resume()
                }
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let totalBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        reportProgress(bytesDownloaded: totalBytesWritten, totalBytes: totalBytes)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: location, to: destinationURL)
            reportProgress(
                bytesDownloaded: fileSize(at: destinationURL),
                totalBytes: expectedByteCount(from: downloadTask.response),
                force: true
            )
            resume(returning: downloadTask.response ?? URLResponse())
        } catch {
            resume(throwing: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        resume(throwing: error)
    }

    private func cancel() {
        lock.lock()
        let task = downloadTask
        lock.unlock()

        task?.cancel()
    }

    private func reportProgress(
        bytesDownloaded: Int64,
        totalBytes: Int64?,
        force: Bool = false
    ) {
        guard let progressHandler else { return }

        let now = Date()
        lock.lock()
        let shouldReport = force || now.timeIntervalSince(lastReportDate) >= reportInterval
        if shouldReport {
            lastReportDate = now
        }
        lock.unlock()

        guard shouldReport else { return }

        let elapsed = now.timeIntervalSince(startedAt)
        let estimatedSecondsRemaining = estimateSecondsRemaining(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            elapsed: elapsed
        )

        progressHandler(
            LocalModelDownloadProgress(
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                estimatedSecondsRemaining: estimatedSecondsRemaining
            )
        )
    }

    private func estimateSecondsRemaining(
        bytesDownloaded: Int64,
        totalBytes: Int64?,
        elapsed: TimeInterval
    ) -> TimeInterval? {
        guard let totalBytes, totalBytes > 0, bytesDownloaded > 0, elapsed > 0 else {
            return nil
        }

        guard bytesDownloaded < totalBytes else {
            return 0
        }

        let bytesPerSecond = Double(bytesDownloaded) / elapsed
        guard bytesPerSecond > 0 else { return nil }

        return Double(totalBytes - bytesDownloaded) / bytesPerSecond
    }

    private func expectedByteCount(from response: URLResponse?) -> Int64? {
        guard let expectedContentLength = response?.expectedContentLength,
              expectedContentLength > 0 else {
            return nil
        }

        return expectedContentLength
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private func resume(returning response: URLResponse) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        downloadTask = nil
        lock.unlock()

        continuation?.resume(returning: response)
    }

    private func resume(throwing error: Error) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        downloadTask = nil
        lock.unlock()

        continuation?.resume(throwing: error)
    }
}

private extension HTTPURLResponse {
    var isSuccessful: Bool {
        (200..<300).contains(statusCode)
    }
}
