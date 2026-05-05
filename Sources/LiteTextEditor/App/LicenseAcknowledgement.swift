import Foundation

struct LicenseAcknowledgement: Identifiable, Equatable {
    let id: String
    let name: String
    let licenseName: String
    let usage: String
    let sourceURL: URL
    private let resourceName: String

    init(
        id: String,
        name: String,
        licenseName: String,
        usage: String,
        sourceURL: URL,
        resourceName: String
    ) {
        self.id = id
        self.name = name
        self.licenseName = licenseName
        self.usage = usage
        self.sourceURL = sourceURL
        self.resourceName = resourceName
    }

    var licenseText: String {
        Bundle.module.licenseText(named: resourceName)
    }
}

enum LicenseAcknowledgements {
    static let all = [
        LicenseAcknowledgement(
            id: "llama-cpp",
            name: "llama.cpp and ggml",
            licenseName: "MIT License",
            usage: "Bundled autocomplete runtime",
            sourceURL: URL(string: "https://github.com/ggml-org/llama.cpp")!,
            resourceName: "llama-cpp-MIT"
        ),
        LicenseAcknowledgement(
            id: "cpp-httplib",
            name: "cpp-httplib",
            licenseName: "MIT License",
            usage: "HTTP server used by llama.cpp",
            sourceURL: URL(string: "https://github.com/yhirose/cpp-httplib")!,
            resourceName: "cpp-httplib-MIT"
        ),
        LicenseAcknowledgement(
            id: "nlohmann-json",
            name: "JSON for Modern C++",
            licenseName: "MIT License",
            usage: "JSON support used by llama.cpp",
            sourceURL: URL(string: "https://github.com/nlohmann/json")!,
            resourceName: "nlohmann-json-MIT"
        ),
        LicenseAcknowledgement(
            id: "qwen2.5-0.5b-instruct-gguf",
            name: "Qwen2.5 0.5B Instruct GGUF",
            licenseName: "Apache License 2.0",
            usage: "On-demand autocomplete model download",
            sourceURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF")!,
            resourceName: "qwen2.5-0.5b-instruct-Apache-2.0"
        )
    ]
}

private extension Bundle {
    func licenseText(named resourceName: String) -> String {
        guard let url = url(forResource: resourceName, withExtension: "txt", subdirectory: "Licenses")
            ?? url(forResource: resourceName, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text is unavailable in this build."
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
