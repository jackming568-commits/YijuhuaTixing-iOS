import Foundation

enum MissingField: String, Codable, CaseIterable, Identifiable {
    case title
    case time
    case date
    case validFutureTime
    case repeatRule
    case unsupportedCondition
    case unsupportedLocation

    var id: String { rawValue }
}

enum ParseSource: String, Codable {
    case localRules = "local_rules"
    case ai
    case hybrid
}

struct ParsedReminder: Codable, Equatable {
    var title: String
    var tag: ReminderTag = .other
    var addressText: String?
    var datetime: Date?
    var repeatRule: RepeatRule?
    var confidence: Double
    var needsUserConfirmation: Bool
    var missingFields: [MissingField]
    var rawInput: String
    var parseSource: ParseSource
    var suggestions: [String]

    var canCreateReminder: Bool {
        !title.isEmpty && datetime != nil && !missingFields.contains(.validFutureTime)
    }
}

enum ParserResult: Equatable {
    case success(ParsedReminder)
    case needsInput(ParsedReminder)
    case failed(ParseFailure)
}

struct ParseFailure: Error, Equatable {
    var rawInput: String
    var message: String
    var missingFields: [MissingField]
    var suggestions: [String]
}
