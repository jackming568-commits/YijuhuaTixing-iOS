import Foundation
import SwiftData

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

    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .pending }
        set {
            statusRaw = newValue.rawValue
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
