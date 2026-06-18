import Foundation
import SwiftData

enum ReminderSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Reminder.self]
    }

    @Model
    final class Reminder: Identifiable {
        @Attribute(.unique) var id: UUID
        var title: String
        var rawInput: String
        var remindAt: Date
        var statusRaw: String
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?
        var lastTriggeredAt: Date?
        var notificationId: String
        var parseConfidence: Double

        var repeatTypeRaw: String
        var repeatInterval: Int
        var repeatWeekday: Int?
        var repeatDayOfMonth: Int?

        init(
            id: UUID = UUID(),
            title: String,
            rawInput: String,
            remindAt: Date,
            repeatRule: RepeatRule? = nil,
            status: ReminderStatus = .pending,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            completedAt: Date? = nil,
            lastTriggeredAt: Date? = nil,
            notificationId: String? = nil,
            parseConfidence: Double = 1
        ) {
            self.id = id
            self.title = title
            self.rawInput = rawInput
            self.remindAt = remindAt
            self.statusRaw = status.rawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.completedAt = completedAt
            self.lastTriggeredAt = lastTriggeredAt
            self.notificationId = notificationId ?? "reminder-\(id.uuidString)"
            self.parseConfidence = parseConfidence

            let rule = repeatRule ?? .none
            self.repeatTypeRaw = rule.type.rawValue
            self.repeatInterval = rule.interval
            self.repeatWeekday = rule.weekday
            self.repeatDayOfMonth = rule.dayOfMonth
        }
    }
}

enum ReminderSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Reminder.self]
    }

    @Model
    final class Reminder: Identifiable {
        @Attribute(.unique) var id: UUID
        var title: String
        var rawInput: String
        var tagRaw: String?
        var remindAt: Date
        var statusRaw: String
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?
        var lastTriggeredAt: Date?
        var notificationId: String
        var parseConfidence: Double

        var repeatTypeRaw: String
        var repeatInterval: Int
        var repeatWeekday: Int?
        var repeatDayOfMonth: Int?

        init(
            id: UUID = UUID(),
            title: String,
            rawInput: String,
            remindAt: Date,
            tag: ReminderTag? = nil,
            repeatRule: RepeatRule? = nil,
            status: ReminderStatus = .pending,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            completedAt: Date? = nil,
            lastTriggeredAt: Date? = nil,
            notificationId: String? = nil,
            parseConfidence: Double = 1
        ) {
            self.id = id
            self.title = title
            self.rawInput = rawInput
            self.tagRaw = tag?.rawValue
            self.remindAt = remindAt
            self.statusRaw = status.rawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.completedAt = completedAt
            self.lastTriggeredAt = lastTriggeredAt
            self.notificationId = notificationId ?? "reminder-\(id.uuidString)"
            self.parseConfidence = parseConfidence

            let rule = repeatRule ?? .none
            self.repeatTypeRaw = rule.type.rawValue
            self.repeatInterval = rule.interval
            self.repeatWeekday = rule.weekday
            self.repeatDayOfMonth = rule.dayOfMonth
        }
    }
}

enum ReminderSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Reminder.self]
    }
}

enum ReminderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ReminderSchemaV1.self, ReminderSchemaV2.self, ReminderSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: ReminderSchemaV1.self, toVersion: ReminderSchemaV2.self),
            .lightweight(fromVersion: ReminderSchemaV2.self, toVersion: ReminderSchemaV3.self)
        ]
    }
}

@Model
final class Reminder: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var rawInput: String
    var tagRaw: String?
    var addressText: String?
    var remindAt: Date
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var lastTriggeredAt: Date?
    var notificationId: String
    var parseConfidence: Double

    var repeatTypeRaw: String
    var repeatInterval: Int
    var repeatWeekday: Int?
    var repeatDayOfMonth: Int?

    init(
        id: UUID = UUID(),
        title: String,
        rawInput: String,
        remindAt: Date,
        tag: ReminderTag? = nil,
        addressText: String? = nil,
        repeatRule: RepeatRule? = nil,
        status: ReminderStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        lastTriggeredAt: Date? = nil,
        notificationId: String? = nil,
        parseConfidence: Double = 1
    ) {
        self.id = id
        self.title = title
        self.rawInput = rawInput
        self.tagRaw = tag?.rawValue
        self.addressText = addressText
        self.remindAt = remindAt
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.lastTriggeredAt = lastTriggeredAt
        self.notificationId = notificationId ?? "reminder-\(id.uuidString)"
        self.parseConfidence = parseConfidence

        let rule = repeatRule ?? .none
        self.repeatTypeRaw = rule.type.rawValue
        self.repeatInterval = rule.interval
        self.repeatWeekday = rule.weekday
        self.repeatDayOfMonth = rule.dayOfMonth
    }

    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .pending }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var tag: ReminderTag {
        get { ReminderTag(rawValue: tagRaw ?? "") ?? .other }
        set {
            tagRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var repeatRule: RepeatRule {
        get {
            RepeatRule(
                type: RepeatRuleType(rawValue: repeatTypeRaw) ?? .none,
                interval: repeatInterval,
                weekday: repeatWeekday,
                dayOfMonth: repeatDayOfMonth
            )
        }
        set {
            repeatTypeRaw = newValue.type.rawValue
            repeatInterval = newValue.interval
            repeatWeekday = newValue.weekday
            repeatDayOfMonth = newValue.dayOfMonth
            updatedAt = Date()
        }
    }

    var isCompleted: Bool {
        status == .completed
    }

    var isDeleted: Bool {
        status == .deleted
    }
}

enum ReminderKeywordMatcher {
    static func matches(reminder: Reminder, keyword: String, actionDate: Date? = nil) -> Bool {
        let tokens = normalizedTokens(from: keyword)
        guard !tokens.isEmpty else {
            return true
        }

        let searchableText = normalized(searchableText(for: reminder, actionDate: actionDate))
        return tokens.allSatisfy { searchableText.contains($0) }
    }

    private static func normalizedTokens(from keyword: String) -> [String] {
        keyword
            .split(whereSeparator: \.isWhitespace)
            .map { normalized(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func searchableText(for reminder: Reminder, actionDate: Date?) -> String {
        var parts = [
            reminder.title,
            reminder.tag.displayName,
            reminder.rawInput,
            DateFormatterProvider.fullDateTimeFormatter.string(from: reminder.remindAt),
            DateFormatterProvider.relativeDayLabel(for: reminder.remindAt)
        ]

        if let actionDate {
            parts.append(DateFormatterProvider.fullDateTimeFormatter.string(from: actionDate))
            parts.append(DateFormatterProvider.relativeDayLabel(for: actionDate))
        }

        return parts.joined(separator: " ")
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh-Hans-CN"))
            .lowercased()
    }
}
