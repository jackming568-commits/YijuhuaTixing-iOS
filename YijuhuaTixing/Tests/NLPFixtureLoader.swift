import Foundation

struct NLPFixture: Decodable {
    struct ExpectedRepeat: Decodable {
        var type: String
        var interval: Int?
        var weekday: Int?
        var dayOfMonth: Int?
    }

    var id: String
    var category: String
    var input: String
    var expectedTitle: String
    var expectedDateTime: String?
    var expectedRepeat: ExpectedRepeat?
    var expectedOutcome: String
    var expectedConfidenceBand: String
    var expectedMissingFields: [String]
    var difficulty: String
}

enum NLPFixtureLoader {
    static func loadFixtures(named name: String = "yijuhua-tixing-nlp-test-corpus-v0.1") throws -> [NLPFixture] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: BundleMarker.self)
        #endif

        guard let url = bundle.url(forResource: name, withExtension: "jsonl") ?? localFallbackURL(named: name) else {
            return []
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        return try content
            .split(separator: "\n")
            .map { line in
                try JSONDecoder().decode(NLPFixture.self, from: Data(line.utf8))
            }
    }

    private static func localFallbackURL(named name: String) -> URL? {
        let candidates = [
            "Tests/Resources/\(name).jsonl",
            "ios/YijuhuaTixing/Tests/Resources/\(name).jsonl",
            "../../yijuhua-tixing-nlp-test-corpus-v0.1.jsonl"
        ]

        return candidates
            .map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private final class BundleMarker {}
