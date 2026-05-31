import Foundation

private struct Fixture: Decodable {
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
    var expectedMissingFields: [String]
    var difficulty: String
}

private struct Failure {
    var id: String
    var input: String
    var reason: String
}

@main
private enum NLPCorpusSmokeTest {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            print("Usage: NLPCorpusSmokeTest <path-to-jsonl>")
            Foundation.exit(2)
        }

        let corpusURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let fixtures = try loadFixtures(from: corpusURL)
        let parser = LocalReminderParser()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = try parseDate("2026-05-24T16:00:00+08:00")

        var failures: [Failure] = []
        var categoryTotals: [String: Int] = [:]
        var categoryFailures: [String: Int] = [:]

        for fixture in fixtures {
            categoryTotals[fixture.category, default: 0] += 1
            let result = parser.parse(fixture.input, now: now, calendar: calendar, settings: .default)
            let reason = validate(result: result, against: fixture)

            if let reason {
                failures.append(Failure(id: fixture.id, input: fixture.input, reason: reason))
                categoryFailures[fixture.category, default: 0] += 1
            }
        }

        let passed = fixtures.count - failures.count
        print("NLP corpus smoke test")
        print("Passed: \(passed)/\(fixtures.count)")

        for category in categoryTotals.keys.sorted() {
            let total = categoryTotals[category, default: 0]
            let failed = categoryFailures[category, default: 0]
            print("- \(category): \(total - failed)/\(total)")
        }

        if !failures.isEmpty {
            print("\nFirst failures:")
            for failure in failures.prefix(20) {
                print("- \(failure.id): \(failure.input) -> \(failure.reason)")
            }
            Foundation.exit(1)
        }
    }

    private static func loadFixtures(from url: URL) throws -> [Fixture] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try content
            .split(separator: "\n")
            .map { line in
                try JSONDecoder().decode(Fixture.self, from: Data(line.utf8))
            }
    }

    private static func validate(result: ParserResult, against fixture: Fixture) -> String? {
        switch (fixture.expectedOutcome, result) {
        case ("success", .success(let parsed)):
            return validateParsed(parsed, fixture: fixture)
        case ("needs_input", .needsInput(let parsed)):
            return validateParsed(parsed, fixture: fixture)
        case ("unsupported", .needsInput(let parsed)):
            return validateParsed(parsed, fixture: fixture)
        case ("conflict", .needsInput(let parsed)):
            return validateParsed(parsed, fixture: fixture)
        case ("success", _):
            return "expected success, got \(outcomeName(for: result))"
        case ("needs_input", _):
            return "expected needs_input, got \(outcomeName(for: result))"
        case ("unsupported", _):
            return "expected unsupported/needsInput, got \(outcomeName(for: result))"
        case ("conflict", _):
            return "expected conflict/needsInput, got \(outcomeName(for: result))"
        default:
            return "unknown expected outcome \(fixture.expectedOutcome)"
        }
    }

    private static func validateParsed(_ parsed: ParsedReminder, fixture: Fixture) -> String? {
        if parsed.title != fixture.expectedTitle {
            return "title expected \(fixture.expectedTitle), got \(parsed.title)"
        }

        if let expectedDateTime = fixture.expectedDateTime {
            guard let parsedDate = parsed.datetime else {
                return "datetime expected \(expectedDateTime), got nil"
            }
            do {
                let expectedDate = try parseDate(expectedDateTime)
                if parsedDate != expectedDate {
                    return "datetime expected \(expectedDateTime), got \(formatDate(parsedDate))"
                }
            } catch {
                return "bad fixture datetime \(expectedDateTime)"
            }
        } else if parsed.datetime != nil && fixture.expectedOutcome != "needs_input" {
            return "datetime expected nil, got \(formatDate(parsed.datetime!))"
        }

        let expectedMissing = Set(fixture.expectedMissingFields)
        let actualMissing = Set(parsed.missingFields.map(\.rawValue))
        if expectedMissing != actualMissing {
            return "missing fields expected \(expectedMissing.sorted()), got \(actualMissing.sorted())"
        }

        if let expectedRepeat = fixture.expectedRepeat {
            guard let repeatRule = parsed.repeatRule else {
                return "repeat expected \(expectedRepeat.type), got nil"
            }
            if repeatRule.type.rawValue != expectedRepeat.type {
                return "repeat type expected \(expectedRepeat.type), got \(repeatRule.type.rawValue)"
            }
            if let expectedInterval = expectedRepeat.interval, repeatRule.interval != expectedInterval {
                return "repeat interval expected \(expectedInterval), got \(repeatRule.interval)"
            }
            if let expectedWeekday = expectedRepeat.weekday, repeatRule.weekday != expectedWeekday {
                return "repeat weekday expected \(expectedWeekday), got \(String(describing: repeatRule.weekday))"
            }
            if let expectedDay = expectedRepeat.dayOfMonth, repeatRule.dayOfMonth != expectedDay {
                return "repeat dayOfMonth expected \(expectedDay), got \(String(describing: repeatRule.dayOfMonth))"
            }
        } else if parsed.repeatRule != nil {
            return "repeat expected nil, got \(parsed.repeatRule!.type.rawValue)"
        }

        return nil
    }

    private static func outcomeName(for result: ParserResult) -> String {
        switch result {
        case .success:
            return "success"
        case .needsInput:
            return "needs_input"
        case .failed:
            return "failed"
        }
    }

    private static func parseDate(_ string: String) throws -> Date {
        guard let date = formatter.date(from: string) else {
            throw CocoaError(.coderInvalidValue)
        }
        return date
    }

    private static func formatDate(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()
}
