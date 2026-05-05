import Foundation

final class LocalModelFileDownloader: NSObject, URLSessionDownloadDelegate {
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
