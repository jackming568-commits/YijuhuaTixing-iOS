import Foundation
import UserNotifications

protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func schedule(reminder: Reminder) async throws
    func cancel(notificationId: String)
}

final class NotificationService: NotificationScheduling {
    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: NotificationActionIdentifier.complete,
            title: "完成",
            options: []
        )

        let snooze10m = UNNotificationAction(
            identifier: NotificationActionIdentifier.snooze10m,
            title: "10分钟后",
            options: []
        )

        let snooze1h = UNNotificationAction(
            identifier: NotificationActionIdentifier.snooze1h,
            title: "1小时后",
            options: []
        )

        let tomorrowMorning = UNNotificationAction(
            identifier: NotificationActionIdentifier.tomorrowMorning,
            title: "明天早上",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationActionIdentifier.category,
            actions: [complete, snooze10m, snooze1h, tomorrowMorning],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    func schedule(reminder: Reminder) async throws {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            throw NotificationError.notAuthorized
        }

        guard reminder.remindAt > Date() else {
            throw NotificationError.invalidPastDate
        }

        let content = UNMutableNotificationContent()
        content.title = "一句话提醒"
        content.body = reminder.title
        content.sound = .default
        content.categoryIdentifier = NotificationActionIdentifier.category
        content.userInfo = ["reminderId": reminder.id.uuidString]

        for requestData in Self.makeRequests(for: reminder, content: content) {
            let request = UNNotificationRequest(
                identifier: requestData.identifier,
                content: content,
                trigger: requestData.trigger
            )
            try await center.add(request)
        }
    }

    static func makeTrigger(for reminder: Reminder, calendar: Calendar = .current) -> UNNotificationTrigger {
        makeTriggers(for: reminder, calendar: calendar)[0].trigger
    }

    static func makeTriggers(
        for reminder: Reminder,
        calendar: Calendar = .current
    ) -> [(identifier: String, trigger: UNNotificationTrigger)] {
        let rule = reminder.repeatRule

        guard reminder.status == .pending else {
            return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
        }

        switch rule.type {
        case .none:
            return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
        case .daily:
            guard rule.interval == 1 else {
                return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
            }
            let components = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [(reminder.notificationId, trigger)]
        case .hourly:
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(rule.interval, 1) * 60 * 60),
                repeats: true
            )
            return [(reminder.notificationId, trigger)]
        case .weekly:
            guard rule.interval == 1 else {
                return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
            }
            var components = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
            components.weekday = rule.weekday.map { appleWeekday(fromMondayBased: $0) } ?? calendar.component(.weekday, from: reminder.remindAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [(reminder.notificationId, trigger)]
        case .monthly:
            guard rule.interval == 1 else {
                return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
            }
            var components = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
            components.day = rule.dayOfMonth ?? calendar.component(.day, from: reminder.remindAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [(reminder.notificationId, trigger)]
        case .weekdays:
            guard rule.interval == 1 else {
                return [(reminder.notificationId, oneTimeTrigger(for: reminder.remindAt, calendar: calendar))]
            }
            let time = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
            return weekdayAppleValues.map { weekday in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = time.hour
                components.minute = time.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                return (weekdayNotificationId(base: reminder.notificationId, appleWeekday: weekday), trigger)
            }
        }
    }

    private static func makeRequests(
        for reminder: Reminder,
        content: UNNotificationContent,
        calendar: Calendar = .current
    ) -> [(identifier: String, trigger: UNNotificationTrigger)] {
        makeTriggers(for: reminder, calendar: calendar).map { ($0.identifier, $0.trigger) }
    }

    private static func oneTimeTrigger(for date: Date, calendar: Calendar) -> UNCalendarNotificationTrigger {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private static func appleWeekday(fromMondayBased weekday: Int) -> Int {
        weekday == 7 ? 1 : weekday + 1
    }

    private static let weekdayAppleValues = [2, 3, 4, 5, 6]

    private static func weekdayNotificationId(base: String, appleWeekday: Int) -> String {
        "\(base).weekday.\(appleWeekday)"
    }

    private static func notificationIds(forBase notificationId: String) -> [String] {
        [notificationId] + weekdayAppleValues.map { weekdayNotificationId(base: notificationId, appleWeekday: $0) }
    }

    func cancel(notificationId: String) {
        let ids = Self.notificationIds(forBase: notificationId)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

enum NotificationError: Error, LocalizedError, Equatable {
    case notAuthorized
    case invalidPastDate

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "通知权限未开启"
        case .invalidPastDate:
            return "提醒时间已经过了"
        }
    }
}
