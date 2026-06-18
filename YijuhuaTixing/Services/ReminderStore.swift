import Foundation
import SwiftData

@MainActor
final class ReminderStore {
    private let context: ModelContext
    private let notificationService: NotificationScheduling
    private let deletedArchive: DeletedReminderArchiving?

    init(
        context: ModelContext,
        notificationService: NotificationScheduling = NotificationService.shared,
        deletedArchive: DeletedReminderArchiving? = DeletedReminderArchive.shared
    ) {
        self.context = context
        self.notificationService = notificationService
        self.deletedArchive = deletedArchive
    }

    func create(from parsed: ParsedReminder, scheduleNotification: Bool = true) async throws -> Reminder {
        guard let remindAt = parsed.datetime else {
            throw ReminderStoreError.missingDate
        }

        let reminder = Reminder(
            title: parsed.title,
            rawInput: parsed.rawInput,
            remindAt: remindAt,
            tag: parsed.tag,
            addressText: normalizedAddressText(parsed.addressText),
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

    func update(
        _ reminder: Reminder,
        title: String,
        remindAt: Date,
        repeatRule: RepeatRule,
        tag: ReminderTag? = nil,
        addressText: String?
    ) async throws {
        let oldTitle = reminder.title
        let oldRemindAt = reminder.remindAt
        let oldRepeatRule = reminder.repeatRule
        let oldTagRaw = reminder.tagRaw
        let oldAddressText = reminder.addressText
        let oldUpdatedAt = reminder.updatedAt

        notificationService.cancel(notificationId: reminder.notificationId)
        reminder.title = title
        reminder.remindAt = remindAt
        reminder.repeatRule = repeatRule
        reminder.addressText = normalizedAddressText(addressText)
        if let tag {
            reminder.tag = tag
        }
        reminder.updatedAt = Date()
        try context.save()

        do {
            try await notificationService.schedule(reminder: reminder)
        } catch {
            reminder.title = oldTitle
            reminder.remindAt = oldRemindAt
            reminder.repeatRule = oldRepeatRule
            reminder.tagRaw = oldTagRaw
            reminder.addressText = oldAddressText
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
        do {
            try deletedArchive?.append(reminder: reminder, deletedAt: Date())
        } catch {
            print("Failed to archive deleted reminder:", error)
        }
    }

    func restoreDeleted(_ reminder: Reminder, status: ReminderStatus = .pending) async throws {
        guard reminder.isDeleted else {
            return
        }

        try await restore(reminder, status: status)
    }

    func restore(_ reminder: Reminder, status: ReminderStatus = .pending, now: Date = Date()) async throws {
        guard reminder.isDeleted || reminder.isCompleted else {
            return
        }

        let wasDeleted = reminder.isDeleted
        let oldStatus = reminder.status
        let oldCompletedAt = reminder.completedAt
        let oldUpdatedAt = reminder.updatedAt

        reminder.status = status
        if status != .completed {
            reminder.completedAt = nil
        }
        reminder.updatedAt = Date()
        try context.save()

        var didSchedule = false
        do {
            if shouldRefreshScheduledNotification(for: reminder, now: now) {
                try await notificationService.schedule(reminder: reminder)
                didSchedule = true
            }
            if wasDeleted {
                try deletedArchive?.removeRecord(id: reminder.id)
            }
        } catch {
            if didSchedule {
                notificationService.cancel(notificationId: reminder.notificationId)
            }
            reminder.status = oldStatus
            reminder.completedAt = oldCompletedAt
            reminder.updatedAt = oldUpdatedAt
            try? context.save()
            throw error
        }
    }

    func permanentlyDelete(_ reminder: Reminder) throws {
        guard canPermanentlyDelete(reminder) else {
            throw ReminderStoreError.notDeleted
        }

        notificationService.cancel(notificationId: reminder.notificationId)
        if reminder.isDeleted {
            try deletedArchive?.removeRecord(id: reminder.id)
        }
        context.delete(reminder)
        try context.save()
    }

    func permanentlyDelete(_ reminders: [Reminder]) throws {
        guard !reminders.isEmpty else {
            return
        }
        guard reminders.allSatisfy(canPermanentlyDelete) else {
            throw ReminderStoreError.notDeleted
        }

        for reminder in reminders {
            notificationService.cancel(notificationId: reminder.notificationId)
        }
        let deletedIds = Set(reminders.filter(\.isDeleted).map(\.id))
        if !deletedIds.isEmpty {
            try deletedArchive?.removeRecords(ids: deletedIds)
        }
        for reminder in reminders {
            context.delete(reminder)
        }
        try context.save()
    }

    func snooze(_ reminder: Reminder, option: SnoozeOption, settings: ParserSettings = .default) async throws {
        notificationService.cancel(notificationId: reminder.notificationId)
        reminder.remindAt = option.targetDate(settings: settings)
        reminder.status = .snoozed
        reminder.updatedAt = Date()
        try context.save()
        try await notificationService.schedule(reminder: reminder)
    }

    func refreshScheduledNotifications(for reminders: [Reminder], now: Date = Date()) async {
        for reminder in reminders where shouldRefreshScheduledNotification(for: reminder, now: now) {
            try? await notificationService.schedule(reminder: reminder)
        }
    }

    func reminder(id: UUID) throws -> Reminder? {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                reminder.id == id
            }
        )
        return try context.fetch(descriptor).first
    }

    private func canPermanentlyDelete(_ reminder: Reminder) -> Bool {
        reminder.isDeleted || reminder.isCompleted
    }

    private func shouldRefreshScheduledNotification(for reminder: Reminder, now: Date) -> Bool {
        reminder.remindAt > now && !reminder.isCompleted && !reminder.isDeleted
    }

    private func normalizedAddressText(_ addressText: String?) -> String? {
        let trimmed = addressText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ReminderStoreError: Error, LocalizedError {
    case missingDate
    case notDeleted

    var errorDescription: String? {
        switch self {
        case .missingDate:
            return "缺少提醒时间"
        case .notDeleted:
            return "只能完全删除已完成或已删除的提醒"
        }
    }
}
