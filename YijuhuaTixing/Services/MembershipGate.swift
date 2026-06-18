import Foundation

enum ProFeature: String, Sendable {
    case reminderDailyLimit = "reminder_daily_limit"
    case voiceInput = "voice_input"
    case tagFilter = "tag_filter"
    case historyRestore = "history_restore"

    var blockedMessage: String {
        switch self {
        case .reminderDailyLimit:
            return MembershipGate.dailyLimitMessage()
        case .voiceInput:
            return "语音输入是 Pro 权益，升级后可以直接说一句创建或搜索提醒。"
        case .tagFilter:
            return "标签筛选是 Pro 权益，升级后可以按场景快速查看提醒。"
        case .historyRestore:
            return "历史恢复是 Pro 权益，升级后可以找回已完成或误删的提醒。"
        }
    }
}

enum MembershipGate {
    static let freeDailyReminderLimit = 3
    #if DEBUG
    static let bypassDailyReminderLimitForDebug = true
    #else
    static let bypassDailyReminderLimitForDebug = false
    #endif

    static func createdTodayCount(
        reminders: [Reminder],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        reminders.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.count
    }

    static func canCreateReminder(
        hasProAccess: Bool,
        reminders: [Reminder],
        now: Date = Date(),
        calendar: Calendar = .current,
        bypassDebugLimit: Bool = bypassDailyReminderLimitForDebug
    ) -> Bool {
        if bypassDebugLimit {
            return true
        }
        return hasProAccess || createdTodayCount(reminders: reminders, now: now, calendar: calendar) < freeDailyReminderLimit
    }

    static func dailyLimitMessage(createdTodayCount: Int? = nil) -> String {
        if let createdTodayCount {
            return "免费版每天最多创建 \(freeDailyReminderLimit) 条提醒，你今天已创建 \(createdTodayCount) 条。升级 Pro 后不限数量。"
        }
        return "免费版每天最多创建 \(freeDailyReminderLimit) 条提醒，升级 Pro 后不限数量。"
    }
}
