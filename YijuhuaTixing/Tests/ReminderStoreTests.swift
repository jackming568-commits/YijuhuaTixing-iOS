import SwiftData
import UserNotifications
import XCTest
@testable import YijuhuaTixing

@MainActor
final class ReminderStoreTests: XCTestCase {
    func testCreatePersistsReminderAndSchedulesNotification() async throws {
        let fixture = try makeStoreFixture()
        let parsed = makeParsedReminder(title: "取快递", rawInput: "10分钟后提醒我取快递")

        let reminder = try await fixture.store.create(from: parsed)

        XCTAssertEqual(reminder.title, "取快递")
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testUpdateCancelsExistingNotificationAndSchedulesUpdatedReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let updatedDate = Date().addingTimeInterval(1_200)

        try await fixture.store.update(
            reminder,
            title: "更新后的提醒",
            remindAt: updatedDate,
            repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
        )

        XCTAssertEqual(reminder.title, "更新后的提醒")
        XCTAssertEqual(reminder.remindAt, updatedDate)
        XCTAssertEqual(reminder.repeatRule.type, .daily)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testUpdateRollsBackReminderWhenSchedulingFails() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let originalTitle = reminder.title
        let originalDate = reminder.remindAt
        let originalRepeatRule = reminder.repeatRule
        fixture.notificationService.scheduleError = NotificationError.notAuthorized

        do {
            try await fixture.store.update(
                reminder,
                title: "更新后的提醒",
                remindAt: Date().addingTimeInterval(1_200),
                repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
            )
            XCTFail("Expected update to throw")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }

        XCTAssertEqual(reminder.title, originalTitle)
        XCTAssertEqual(reminder.remindAt, originalDate)
        XCTAssertEqual(reminder.repeatRule, originalRepeatRule)
    }

    func testCompleteOneTimeReminderCancelsNotificationAndMarksCompleted() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try await fixture.store.complete(reminder)

        XCTAssertEqual(reminder.status, .completed)
        XCTAssertNotNil(reminder.completedAt)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertTrue(fixture.notificationService.scheduledIds.isEmpty)
    }

    func testCompleteRepeatingReminderAdvancesDateAndReschedules() async throws {
        let fixture = try makeStoreFixture()
        let startDate = Date().addingTimeInterval(600)
        let reminder = try await fixture.store.create(
            from: makeParsedReminder(
                datetime: startDate,
                repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
            ),
            scheduleNotification: false
        )

        try await fixture.store.complete(reminder)

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertEqual(reminder.remindAt, Calendar.current.date(byAdding: .day, value: 1, to: startDate))
        XCTAssertNotNil(reminder.lastTriggeredAt)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testCompleteHourlyRepeatingReminderAdvancesByIntervalAndReschedules() async throws {
        let fixture = try makeStoreFixture()
        let startDate = Date().addingTimeInterval(600)
        let reminder = try await fixture.store.create(
            from: makeParsedReminder(
                datetime: startDate,
                repeatRule: RepeatRule(type: .hourly, interval: 2, weekday: nil, dayOfMonth: nil)
            ),
            scheduleNotification: false
        )

        try await fixture.store.complete(reminder)

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertEqual(reminder.remindAt, Calendar.current.date(byAdding: .hour, value: 2, to: startDate))
        XCTAssertNotNil(reminder.lastTriggeredAt)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testDeleteCancelsNotificationAndSoftDeletesReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try fixture.store.delete(reminder)

        XCTAssertEqual(reminder.status, .deleted)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertTrue(fixture.notificationService.scheduledIds.isEmpty)
    }

    func testRestoreDeletedReminderReschedulesFutureReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try fixture.store.delete(reminder)
        try await fixture.store.restoreDeleted(reminder)

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testRestoreDeletedReminderRollsBackWhenSchedulingFails() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try fixture.store.delete(reminder)
        fixture.notificationService.scheduleError = NotificationError.notAuthorized

        do {
            try await fixture.store.restoreDeleted(reminder)
            XCTFail("Expected restore to throw")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }

        XCTAssertEqual(reminder.status, .deleted)
    }

    func testSnoozeCancelsNotificationAndSchedulesOneTimeReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try await fixture.store.snooze(reminder, option: .minutes(10))

        XCTAssertEqual(reminder.status, .snoozed)
        XCTAssertGreaterThan(reminder.remindAt, Date())
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testSnoozeRepeatingReminderKeepsRepeatRule() async throws {
        let fixture = try makeStoreFixture()
        let repeatRule = RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
        let reminder = try await fixture.store.create(
            from: makeParsedReminder(repeatRule: repeatRule),
            scheduleNotification: false
        )

        try await fixture.store.snooze(reminder, option: .minutes(30))

        XCTAssertEqual(reminder.status, .snoozed)
        XCTAssertEqual(reminder.repeatRule, repeatRule)
    }

    private func makeStoreFixture() throws -> (
        container: ModelContainer,
        notificationService: MockNotificationService,
        store: ReminderStore
    ) {
        let container = try ModelContainer(
            for: Reminder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let notificationService = MockNotificationService()
        let store = ReminderStore(context: container.mainContext, notificationService: notificationService)
        return (container, notificationService, store)
    }

    private func makeParsedReminder(
        title: String = "取快递",
        datetime: Date = Date().addingTimeInterval(600),
        repeatRule: RepeatRule? = nil,
        rawInput: String = "10分钟后提醒我取快递"
    ) -> ParsedReminder {
        ParsedReminder(
            title: title,
            datetime: datetime,
            repeatRule: repeatRule,
            confidence: 0.95,
            needsUserConfirmation: true,
            missingFields: [],
            rawInput: rawInput,
            parseSource: .localRules,
            suggestions: []
        )
    }
}

private final class MockNotificationService: NotificationScheduling {
    var scheduledIds: [String] = []
    var canceledIds: [String] = []
    var scheduleError: Error?

    func authorizationStatus() async -> UNAuthorizationStatus {
        .authorized
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func schedule(reminder: Reminder) async throws {
        if let scheduleError {
            throw scheduleError
        }
        scheduledIds.append(reminder.notificationId)
    }

    func cancel(notificationId: String) {
        canceledIds.append(notificationId)
    }
}

final class NotificationActionRouterTests: XCTestCase {
    func testQueuesCompleteActionUntilHandlersAreConfigured() {
        let router = makeRouter()
        let reminderId = UUID()
        var completedIds: [UUID] = []

        router.handle(actionIdentifier: NotificationActionIdentifier.complete, reminderId: reminderId)
        XCTAssertTrue(completedIds.isEmpty)

        router.configure { id in
            completedIds.append(id)
        } onSnooze: { _, _ in
            XCTFail("Expected complete action")
        }

        XCTAssertEqual(completedIds, [reminderId])
    }

    func testRoutesSnoozeActionWhenHandlersAreConfigured() {
        let router = makeRouter()
        let reminderId = UUID()
        var snoozedActions: [(UUID, SnoozeOption)] = []

        router.configure { _ in
            XCTFail("Expected snooze action")
        } onSnooze: { id, option in
            snoozedActions.append((id, option))
        }

        router.handle(actionIdentifier: NotificationActionIdentifier.snooze10m, reminderId: reminderId)

        XCTAssertEqual(snoozedActions.count, 1)
        XCTAssertEqual(snoozedActions.first?.0, reminderId)
        XCTAssertEqual(snoozedActions.first?.1, .minutes(10))
    }

    func testPersistsQueuedActionAcrossRouterInstances() {
        let storageKey = "pendingActions.\(UUID().uuidString)"
        let defaults = makeDefaults()
        let reminderId = UUID()
        var completedIds: [UUID] = []

        NotificationActionRouter(defaults: defaults, storageKey: storageKey)
            .handle(actionIdentifier: NotificationActionIdentifier.complete, reminderId: reminderId)

        NotificationActionRouter(defaults: defaults, storageKey: storageKey)
            .configure { id in
                completedIds.append(id)
            } onSnooze: { _, _ in
                XCTFail("Expected complete action")
            }

        XCTAssertEqual(completedIds, [reminderId])
    }

    func testClearsPersistedActionAfterFlush() {
        let storageKey = "pendingActions.\(UUID().uuidString)"
        let defaults = makeDefaults()
        let reminderId = UUID()
        var completedCount = 0

        NotificationActionRouter(defaults: defaults, storageKey: storageKey)
            .handle(actionIdentifier: NotificationActionIdentifier.complete, reminderId: reminderId)

        NotificationActionRouter(defaults: defaults, storageKey: storageKey)
            .configure { _ in
                completedCount += 1
            } onSnooze: { _, _ in }

        NotificationActionRouter(defaults: defaults, storageKey: storageKey)
            .configure { _ in
                completedCount += 1
            } onSnooze: { _, _ in }

        XCTAssertEqual(completedCount, 1)
    }

    private func makeRouter() -> NotificationActionRouter {
        NotificationActionRouter(defaults: makeDefaults(), storageKey: "pendingActions.\(UUID().uuidString)")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "NotificationActionRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

final class NotificationServiceTriggerTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    func testDailyRepeatUsesRepeatingHourMinuteTrigger() throws {
        let reminder = Reminder(
            title: "吃药",
            rawInput: "每天早上8点提醒我吃药",
            remindAt: try date("2026-05-25T08:00:00+08:00"),
            repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
        )

        let trigger = try calendarTrigger(for: reminder)

        XCTAssertTrue(trigger.repeats)
        XCTAssertNil(trigger.dateComponents.year)
        XCTAssertNil(trigger.dateComponents.month)
        XCTAssertNil(trigger.dateComponents.day)
        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    func testWeeklyRepeatUsesWeekdayHourMinuteTrigger() throws {
        let reminder = Reminder(
            title: "周报",
            rawInput: "每周五18点提醒我写周报",
            remindAt: try date("2026-05-29T18:00:00+08:00"),
            repeatRule: RepeatRule(type: .weekly, interval: 1, weekday: 5, dayOfMonth: nil)
        )

        let trigger = try calendarTrigger(for: reminder)

        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.weekday, 6)
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    func testWeekdayRepeatUsesFiveRepeatingWeekdayTriggers() throws {
        let reminder = Reminder(
            title: "打卡",
            rawInput: "工作日早上9点提醒我打卡",
            remindAt: try date("2026-05-25T09:00:00+08:00"),
            repeatRule: RepeatRule(type: .weekdays, interval: 1, weekday: nil, dayOfMonth: nil)
        )

        let triggers = NotificationService.makeTriggers(for: reminder, calendar: calendar)

        XCTAssertEqual(triggers.count, 5)
        let calendarTriggers = try triggers.map { try XCTUnwrap($0.trigger as? UNCalendarNotificationTrigger) }
        XCTAssertEqual(calendarTriggers.map { $0.dateComponents.weekday }, [2, 3, 4, 5, 6])
        XCTAssertTrue(calendarTriggers.allSatisfy { $0.repeats })
        XCTAssertTrue(calendarTriggers.allSatisfy { $0.dateComponents.hour == 9 })
        XCTAssertTrue(calendarTriggers.allSatisfy { $0.dateComponents.minute == 0 })
        XCTAssertTrue(triggers.allSatisfy { $0.identifier.hasPrefix(reminder.notificationId) })
    }

    func testHourlyRepeatUsesRepeatingTimeIntervalTrigger() throws {
        let reminder = Reminder(
            title: "喝水",
            rawInput: "每隔两小时提醒我喝水",
            remindAt: try date("2026-05-24T18:30:00+08:00"),
            repeatRule: RepeatRule(type: .hourly, interval: 2, weekday: nil, dayOfMonth: nil)
        )

        let trigger = try XCTUnwrap(NotificationService.makeTrigger(for: reminder, calendar: calendar) as? UNTimeIntervalNotificationTrigger)

        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.timeInterval, 2 * 60 * 60)
    }

    func testSnoozedRepeatUsesOneTimeTrigger() throws {
        let reminder = Reminder(
            title: "吃药",
            rawInput: "每天早上8点提醒我吃药",
            remindAt: try date("2026-05-25T08:10:00+08:00"),
            repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil),
            status: .snoozed
        )

        let trigger = try calendarTrigger(for: reminder)

        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.year, 2026)
        XCTAssertEqual(trigger.dateComponents.month, 5)
        XCTAssertEqual(trigger.dateComponents.day, 25)
        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 10)
    }

    private func date(_ string: String) throws -> Date {
        guard let date = ISO8601DateFormatter.yijuhua.date(from: string) else {
            throw NotificationServiceTriggerTestError.badDate
        }
        return date
    }

    private func calendarTrigger(for reminder: Reminder) throws -> UNCalendarNotificationTrigger {
        try XCTUnwrap(NotificationService.makeTrigger(for: reminder, calendar: calendar) as? UNCalendarNotificationTrigger)
    }
}

final class DateFormatterProviderTests: XCTestCase {
    func testOverdueLabelUsesMinutesForRecentPastDate() throws {
        let calendar = makeCalendar()
        let now = try date("2026-05-26T10:10:00+08:00", calendar: calendar)
        let past = try date("2026-05-26T10:08:00+08:00", calendar: calendar)

        XCTAssertEqual(DateFormatterProvider.overdueLabel(for: past, now: now, calendar: calendar), "已过 2 分钟")
    }

    func testOverdueLabelUsesHoursBeforeDays() throws {
        let calendar = makeCalendar()
        let now = try date("2026-05-26T12:00:00+08:00", calendar: calendar)
        let past = try date("2026-05-26T09:30:00+08:00", calendar: calendar)

        XCTAssertEqual(DateFormatterProvider.overdueLabel(for: past, now: now, calendar: calendar), "已过 2 小时")
    }

    func testOverdueLabelUsesDaysForOlderPastDate() throws {
        let calendar = makeCalendar()
        let now = try date("2026-05-26T12:00:00+08:00", calendar: calendar)
        let past = try date("2026-05-24T12:00:00+08:00", calendar: calendar)

        XCTAssertEqual(DateFormatterProvider.overdueLabel(for: past, now: now, calendar: calendar), "已过 2 天")
    }

    func testSnoozedLabelUsesReminderTime() throws {
        let calendar = makeCalendar()
        let snoozedDate = try date("2026-05-26T14:30:00+08:00", calendar: calendar)

        XCTAssertEqual(DateFormatterProvider.snoozedLabel(for: snoozedDate), "已延后到 14:30")
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ isoString: String, calendar: Calendar) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: isoString) else {
            throw NSError(domain: "DateFormatterProviderTests", code: 1)
        }
        return date
    }
}

private enum NotificationServiceTriggerTestError: Error {
    case badDate
}

private extension ISO8601DateFormatter {
    static let yijuhua: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
