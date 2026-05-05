import Dispatch
import Foundation

final class LlamaServerTextGenerator: LocalModelTextGenerating {
    private enum Availability {
        case unknown
        case available
        case unavailable(Date)
    }

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let temperature: Double
        let topP: Double
        let minP: Double
        let maxTokens: Int
        let repeatPenalty: Double
        let repeatLastN: Int
        let stop: [String]

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case stream
            case temperature
            case topP = "top_p"
            case minP = "min_p"
            case maxTokens = "max_tokens"
            case repeatPenalty = "repeat_penalty"
            case repeatLastN = "repeat_last_n"
            case stop
        }
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatCompletionResponse: Decodable {
        let choices: [ChatChoice]
    }

    private struct ChatChoice: Decodable {
        let message: ChatMessage?
    }

    private enum GeneratorError: Error {
        case missingRuntime
        case missingModelFile
        case unavailable
        case unexpectedStatus
    }

    private static let defaultPort = 11436
    private static let defaultModelDownloadURLString = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/df5bf01389a39c743ab467d734bf501681e041c5/qwen2.5-0.5b-instruct-q4_k_m.gguf"
    private static let defaultModelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

    private let model: String
    private let modelAlias: String
    private let baseURL: URL
    private let modelFileURL: URL
    private let downloadURL: URL
    private let runtimeExecutableURL: URL?
    private let contextSize: Int
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

    var modelDownloadSourceURL: URL {
        downloadURL
    }

    init(
        model: String = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_LLAMA_MODEL_NAME"] ?? "Qwen 2.5 0.5B Instruct",
        modelAlias: String = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_LLAMA_MODEL_ALIAS"] ?? "lite-text-editor-qwen-document-autocomplete",
        baseURL: URL = LlamaServerTextGenerator.defaultBaseURL(),
        modelFileURL: URL = LlamaServerTextGenerator.defaultModelFileURL(),
        downloadURL: URL = LlamaServerTextGenerator.defaultDownloadURL(),
        runtimeExecutableURL: URL? = LlamaServerTextGenerator.defaultRuntimeExecutableURL(),
        contextSize: Int = 2048,
        timeout: TimeInterval = 1.5,
        downloadTimeout: TimeInterval = 600,
        retryDelay: TimeInterval = 20,
        session: URLSession = .shared
    ) {
        self.model = model
        self.modelAlias = modelAlias
        self.baseURL = baseURL
        self.modelFileURL = modelFileURL
        self.downloadURL = downloadURL
        self.runtimeExecutableURL = runtimeExecutableURL
        self.contextSize = contextSize
        self.timeout = timeout
        self.downloadTimeout = downloadTimeout
        self.retryDelay = retryDelay
        self.session = session
    }

    deinit {
        stopServerProcess()
    }

    func load() async throws {
        if isLoaded { return }
        guard hasDownloadedModelFile() else { throw GeneratorError.missingModelFile }
        guard shouldProbeAvailability() else { throw GeneratorError.unavailable }

        do {
            try await ensureServerReady()
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
        stopServerProcess()

        do {
            try removeDownloadedModelFile()
            markUnavailable()
        } catch {
            markUnavailable()
            throw error
        }
    }

    func completion(for prompt: String) -> String? {
        guard isLoaded else { return nil }

        let body = ChatCompletionRequest(
            model: modelAlias,
            messages: [
                ChatMessage(
                    role: "system",
                    content: """
                    You are Lite Text Editor's private local autocomplete engine.
                    Continue the user's document at the cursor.
                    Return only the exact words to insert.
                    Do not answer the document, summarize it, explain, quote, or add labels.
                    """
                ),
                ChatMessage(role: "user", content: prompt)
            ],
            stream: false,
            temperature: 0.15,
            topP: 0.9,
            minP: 0.05,
            maxTokens: 18,
            repeatPenalty: 1.22,
            repeatLastN: 128,
            stop: ["\n", "[CURSOR]", "Completion:", "Suggestion:", "<|im_end|>"]
        )

        guard let httpBody = try? JSONEncoder().encode(body) else { return nil }

        var request = URLRequest(url: endpoint("v1", "chat", "completions"))
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
            guard (response as? HTTPURLResponse)?.isLocalModelSuccessful == true else {
                self.markUnavailable()
                return
            }
            guard let data else { return }
            guard let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data) else { return }

            completion = decoded.choices.first?.message?.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        task.resume()

        if semaphore.wait(timeout: .now() + timeout + 0.5) == .timedOut {
            task.cancel()
            return nil
        }

        return completion?.isEmpty == true ? nil : completion
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
            let downloader = LocalModelFileDownloader(
                destinationURL: partialURL,
                progressHandler: progressHandler
            )
            let response = try await downloader.download(request: request)
            guard (response as? HTTPURLResponse)?.isLocalModelSuccessful == true else {
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

    private func ensureServerReady() async throws {
        if await isServerReady() {
            return
        }

        try startAppManagedServer()

        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            try Task.checkCancellation()

            if await isServerReady() {
                return
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        throw GeneratorError.unavailable
    }

    private func isServerReady() async -> Bool {
        var request = URLRequest(url: endpoint("health"))
        request.timeoutInterval = 0.35

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.isLocalModelSuccessful == true
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

        guard let runtimeExecutableURL,
              FileManager.default.isExecutableFile(atPath: runtimeExecutableURL.path) else {
            throw GeneratorError.missingRuntime
        }

        let process = Process()
        process.executableURL = runtimeExecutableURL
        process.arguments = [
            "--model", modelFileURL.path,
            "--alias", modelAlias,
            "--host", host,
            "--port", "\(port)",
            "--ctx-size", "\(contextSize)",
            "--parallel", "1",
            "--threads-http", "1",
            "--no-webui"
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["LLAMA_ARG_NO_WEBUI"] = "1"
        process.environment = environment

        if let nullHandle = FileHandle(forWritingAtPath: "/dev/null") {
            process.standardOutput = nullHandle
            process.standardError = nullHandle
        }

        try process.run()
        serverProcess = process
    }

    private func stopServerProcess() {
        stateLock.lock()
        let process = serverProcess
        serverProcess = nil
        availability = .unavailable(Date())
        stateLock.unlock()

        guard process?.isRunning == true else { return }
        process?.terminate()
    }

    private var host: String {
        baseURL.host ?? "127.0.0.1"
    }

    private var port: Int {
        baseURL.port ?? Self.defaultPort
    }

    private func endpoint(_ pathComponents: String...) -> URL {
        pathComponents.reduce(baseURL) { url, component in
            url.appendingPathComponent(component)
        }
    }

    private static func defaultBaseURL() -> URL {
        if let rawURL = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_LLAMA_BASE_URL"],
           let url = URL(string: rawURL) {
            return url
        }

        return URL(string: "http://127.0.0.1:\(defaultPort)")!
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

    private static func defaultRuntimeExecutableURL() -> URL? {
        if let rawPath = ProcessInfo.processInfo.environment["LITE_TEXT_EDITOR_LLAMA_SERVER_PATH"],
           FileManager.default.isExecutableFile(atPath: rawPath) {
            return URL(fileURLWithPath: rawPath)
        }

        let bundledURL = Bundle.main.resourceURL?
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("llama-server")

        guard let bundledURL,
              FileManager.default.isExecutableFile(atPath: bundledURL.path) else {
            return nil
        }

        return bundledURL
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

private extension HTTPURLResponse {
    var isLocalModelSuccessful: Bool {
        (200..<300).contains(statusCode)
    }
}
