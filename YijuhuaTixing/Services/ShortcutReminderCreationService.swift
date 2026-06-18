import Foundation
import SwiftData
import UserNotifications

struct ShortcutReminderCreationResult {
    enum Status: Equatable {
        case created
        case notificationPermissionRequired
        case membershipRequired
        case needsMoreInfo
        case failed
    }

    var status: Status
    var dialog: String
    var title: String?
    var remindAt: Date?
}

@MainActor
struct ShortcutReminderCreationService {
    var container: ModelContainer
    var parser: ReminderParsing = LocalReminderParser()
    var notificationService: NotificationScheduling = NotificationService.shared
    var membershipStorage: MembershipEntitlementStoring = UserDefaultsMembershipEntitlementStorage()
    var now: () -> Date = Date.init
    var calendar: Calendar = .current
    var settings: ParserSettings = .default

    func createReminder(from text: String) async -> ShortcutReminderCreationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return ShortcutReminderCreationResult(
                status: .needsMoreInfo,
                dialog: "请说清楚要创建的提醒内容和时间。",
                title: nil,
                remindAt: nil
            )
        }

        let status = await notificationService.authorizationStatus()
        guard status == .authorized || status == .provisional else {
            AppAnalytics.shared.track(.siriReminderFailed, properties: ["reason": "notification_permission_required"])
            return ShortcutReminderCreationResult(
                status: .notificationPermissionRequired,
                dialog: "还没有开启通知权限，请先打开一句话提醒开启通知。",
                title: nil,
                remindAt: nil
            )
        }

        let parseResult = parser.parse(trimmedText, now: now(), calendar: calendar, settings: settings)
        guard let parsed = parsedReminder(from: parseResult), parsed.canCreateReminder else {
            AppAnalytics.shared.track(.siriReminderFailed, properties: ["reason": "needs_more_info"])
            return reminderNeedsMoreInfoResult(from: parseResult)
        }

        guard membershipStorage.loadEntitlement()?.grantsProAccess == true else {
            AppAnalytics.shared.track(
                .proFeatureBlocked,
                properties: ["feature": "shortcut_creation", "source": "app_intent"]
            )
            AppAnalytics.shared.track(.siriReminderFailed, properties: ["reason": "membership_required"])
            return ShortcutReminderCreationResult(
                status: .membershipRequired,
                dialog: "Siri / 快捷指令创建提醒是 Pro 权益，请先打开一句话提醒升级 Pro。",
                title: nil,
                remindAt: nil
            )
        }

        do {
            let reminder = try await ReminderStore(
                context: container.mainContext,
                notificationService: notificationService
            ).create(from: parsed)
            AppAnalytics.shared.track(
                .siriReminderCreated,
                properties: [
                    "tag": reminder.tag.rawValue,
                    "time_bucket": analyticsTimeBucket(for: reminder.remindAt),
                    "has_repeat": "\(reminder.repeatRule.type != .none)"
                ]
            )
            return ShortcutReminderCreationResult(
                status: .created,
                dialog: "已创建提醒：\(reminder.title)，\(formattedTime(for: reminder.remindAt))",
                title: reminder.title,
                remindAt: reminder.remindAt
            )
        } catch {
            AppAnalytics.shared.track(.siriReminderFailed, properties: ["reason": "create_failed"])
            return ShortcutReminderCreationResult(
                status: .failed,
                dialog: "创建提醒失败，请稍后再试。",
                title: nil,
                remindAt: nil
            )
        }
    }

    private func parsedReminder(from result: ParserResult) -> ParsedReminder? {
        switch result {
        case .success(let parsed), .needsInput(let parsed):
            return parsed
        case .failed:
            return nil
        }
    }

    private func reminderNeedsMoreInfoResult(from result: ParserResult) -> ShortcutReminderCreationResult {
        let dialog: String
        if let parsed = parsedReminder(from: result) {
            dialog = needsMoreInfoDialog(for: parsed)
        } else {
            dialog = "没有识别出有效提醒，请重新说一遍任务和时间。"
        }

        return ShortcutReminderCreationResult(
            status: .needsMoreInfo,
            dialog: dialog,
            title: nil,
            remindAt: nil
        )
    }

    private func needsMoreInfoDialog(for parsed: ParsedReminder) -> String {
        if parsed.missingFields.contains(.validFutureTime) {
            return "这个提醒时间已经过了，请说一个未来时间。"
        }
        if parsed.missingFields.contains(.unsupportedCondition) || parsed.missingFields.contains(.unsupportedLocation) {
            return "这个提醒说法暂时不支持，请换一种更明确的时间和任务。"
        }
        if parsed.missingFields.contains(.title),
           parsed.missingFields.contains(.time) || parsed.missingFields.contains(.date) {
            return "请说清楚要提醒的任务和时间。"
        }
        if parsed.missingFields.contains(.title) {
            return "请说清楚要提醒你的任务内容。"
        }
        if parsed.missingFields.contains(.time) || parsed.missingFields.contains(.date) || parsed.datetime == nil {
            return "请说清楚提醒时间。"
        }
        return "没有识别出完整提醒，请重新说一遍任务和时间。"
    }

    private func formattedTime(for date: Date) -> String {
        "\(DateFormatterProvider.relativeDayLabel(for: date, calendar: calendar)) \(DateFormatterProvider.timeFormatter.string(from: date))"
    }

    private func analyticsTimeBucket(for date: Date) -> String {
        switch ReminderArchivePeriod.period(for: date, now: now(), calendar: calendar, includeOverdue: true) {
        case .overdue:
            return "overdue"
        case .today:
            return "today"
        case .thisWeek:
            return "this_week"
        case .nextWeek:
            return "next_week"
        case .thisMonth:
            return "this_month"
        case .nextMonth:
            return "next_month"
        case .thisQuarter:
            return "this_quarter"
        case .thisHalfYear:
            return "half_year"
        case .thisYear:
            return "one_year"
        case .twoYears:
            return "two_years"
        case .threeYears:
            return "three_years"
        case .fourYears:
            return "four_years"
        case .fiveYears:
            return "five_years"
        case .beyondFiveYears:
            return "after_five_years"
        }
    }
}
