import AppKit

final class DocumentFileService {
    private let store: DocumentFileStore
    private let queue = DispatchQueue(
        label: "LiteTextEditor.DocumentFileService",
        qos: .userInitiated
    )

    init(store: DocumentFileStore = DocumentFileStore()) {
        self.store = store
    }

    func readDocument(
        from url: URL,
        completion: @escaping (Result<NSAttributedString, Error>) -> Void
    ) {
        queue.async { [store] in
            let result = Result {
                try store.readDocument(from: url)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func writeDocument(
        _ attributedString: NSAttributedString,
        to url: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async { [store] in
            let result = Result {
                try store.writeDocument(attributedString, to: url)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func writePDF(
        _ attributedString: NSAttributedString,
        to url: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async { [store] in
            let result = Result {
                try store.writePDF(attributedString, to: url)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
