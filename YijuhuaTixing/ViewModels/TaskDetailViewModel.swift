import Foundation
import Observation

@Observable
final class TaskDetailViewModel {
    var title: String
    var remindAt: Date
    var repeatRule: RepeatRule
    var errorMessage: String?
    private var originalTitle: String
    private var originalRemindAt: Date
    private var originalRepeatRule: RepeatRule

    init(reminder: Reminder) {
        self.title = reminder.title
        self.remindAt = reminder.remindAt
        self.repeatRule = reminder.repeatRule
        self.originalTitle = reminder.title
        self.originalRemindAt = reminder.remindAt
        self.originalRepeatRule = reminder.repeatRule
    }

    var hasChanges: Bool {
        title != originalTitle || remindAt != originalRemindAt || repeatRule != originalRepeatRule
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
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
        remindAt = reminder.remindAt
        repeatRule = reminder.repeatRule
        originalTitle = reminder.title
        originalRemindAt = reminder.remindAt
        originalRepeatRule = reminder.repeatRule
    }
}
