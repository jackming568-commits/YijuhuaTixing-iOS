import Foundation
import Observation

@Observable
final class TaskDetailViewModel {
    var title: String
    var tag: ReminderTag
    var addressText: String
    var remindAt: Date
    var repeatRule: RepeatRule
    var errorMessage: String?
    private var originalTitle: String
    private var originalTag: ReminderTag
    private var originalAddressText: String
    private var originalRemindAt: Date
    private var originalRepeatRule: RepeatRule

    init(reminder: Reminder) {
        self.title = reminder.title
        self.tag = reminder.tag
        self.addressText = reminder.addressText ?? ""
        self.remindAt = reminder.remindAt
        self.repeatRule = reminder.repeatRule
        self.originalTitle = reminder.title
        self.originalTag = reminder.tag
        self.originalAddressText = reminder.addressText ?? ""
        self.originalRemindAt = reminder.remindAt
        self.originalRepeatRule = reminder.repeatRule
    }

    var hasChanges: Bool {
        title != originalTitle
            || tag != originalTag
            || normalizedAddressText != normalizedOriginalAddressText
            || remindAt != originalRemindAt
            || repeatRule != originalRepeatRule
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAddressText: String {
        addressText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedAddressText: String? {
        trimmedAddressText.isEmpty ? nil : trimmedAddressText
    }

    var hasAddress: Bool {
        normalizedAddressText != nil
    }

    var validationMessage: String? {
        if trimmedTitle.isEmpty {
            return "请输入提醒标题"
        }

        if remindAt <= Date() {
            return "请选择一个未来时间"
        }

        return nil
    }

    var canSave: Bool {
        hasChanges && validationMessage == nil
    }

    func sync(from reminder: Reminder) {
        title = reminder.title
        tag = reminder.tag
        addressText = reminder.addressText ?? ""
        remindAt = reminder.remindAt
        repeatRule = reminder.repeatRule
        originalTitle = reminder.title
        originalTag = reminder.tag
        originalAddressText = reminder.addressText ?? ""
        originalRemindAt = reminder.remindAt
        originalRepeatRule = reminder.repeatRule
    }

    private var normalizedOriginalAddressText: String? {
        let trimmed = originalAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
