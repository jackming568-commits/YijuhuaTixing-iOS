import Foundation
import SwiftData

@MainActor
final class ReminderStore {
    private let context: ModelContext
    private let notificationService: NotificationScheduling

    init(context: ModelContext, notificationService: NotificationScheduling = NotificationService.shared) {
        self.context = context
        self.notificationService = notificationService
    }

    func create(from parsed: ParsedReminder, scheduleNotification: Bool = true) async throws -> Reminder {
        guard let remindAt = parsed.datetime else {
            throw ReminderStoreError.missingDate
        }

        let reminder = Reminder(
            title: parsed.title,
            rawInput: parsed.rawInput,
            remindAt: remindAt,
            repeatRule: parsed.repeatRule,
            parseConfidence: parsed.confidence
        )

        context.insert(reminder)
        try context.save()

        if scheduleNotification {
            do {
                try await notificationService.schedule(reminder: reminder)
            } catch {
                context.delete(reminder)
                try? context.save()
                throw error
            }
        }

        return reminder
    }

    func update(_ reminder: Reminder, title: String, remindAt: Date, repeatRule: RepeatRule) async throws {
        let oldTitle = reminder.title
        let oldRemindAt = reminder.remindAt
        let oldRepeatRule = reminder.repeatRule
        let oldUpdatedAt = reminder.updatedAt

        notificationService.cancel(notificationId: reminder.notificationId)
        reminder.title = title
        reminder.remindAt = remindAt
        reminder.repeatRule = repeatRule
        reminder.updatedAt = Date()
        try context.save()

        do {
            try await notificationService.schedule(reminder: reminder)
        } catch {
            reminder.title = oldTitle
            reminder.remindAt = oldRemindAt
            reminder.repeatRule = oldRepeatRule
            reminder.updatedAt = oldUpdatedAt
            try? context.save()
            if oldRemindAt > Date(), !reminder.isCompleted, !reminder.isDeleted {
                try? await notificationService.schedule(reminder: reminder)
            }
            throw error
        }
    }

    func complete(_ reminder: Reminder) async throws {
        notificationService.cancel(notificationId: reminder.notificationId)

        if let nextDate = reminder.repeatRule.nextDate(after: reminder.remindAt), reminder.repeatRule.isRepeating {
            reminder.remindAt = nextDate
            reminder.lastTriggeredAt = Date()
            reminder.status = .pending
            try context.save()
            try await notificationService.schedule(reminder: reminder)
        } else {
            reminder.status = .completed
            reminder.completedAt = Date()
            try context.save()
        }
    }

    func delete(_ reminder: Reminder) throws {
        notificationService.cancel(notificationId: reminder.notificationId)
        reminder.status = .deleted
        reminder.updatedAt = Date()
        try context.save()
    }

    func restoreDeleted(_ reminder: Reminder, status: ReminderStatus = .pending) async throws {
        guard reminder.isDeleted else {
            return
        }

        reminder.status = status
        reminder.updatedAt = Date()
        try context.save()

        do {
            if reminder.remindAt > Date(), !reminder.isCompleted, !reminder.isDeleted {
                try await notificationService.schedule(reminder: reminder)
            }
        } catch {
            reminder.status = .deleted
            reminder.updatedAt = Date()
            try? context.save()
            throw error
        }
    }

    func snooze(_ reminder: Reminder, option: SnoozeOption, settings: ParserSettings = .default) async throws {
        notificationService.cancel(notificationId: reminder.notificationId)
        reminder.remindAt = option.targetDate(settings: settings)
        reminder.status = .snoozed
        reminder.updatedAt = Date()
        try context.save()
        try await notificationService.schedule(reminder: reminder)
    }

    func reminder(id: UUID) throws -> Reminder? {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                reminder.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
}

enum ReminderStoreError: Error, LocalizedError {
    case missingDate

    var errorDescription: String? {
        switch self {
        case .missingDate:
            return "缺少提醒时间"
        }
    }
}
