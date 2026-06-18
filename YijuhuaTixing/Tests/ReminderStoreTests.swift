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
        XCTAssertEqual(reminder.tag, .dailyLife)
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testCreatePersistsTrimmedAddressText() async throws {
        let fixture = try makeStoreFixture()
        let parsed = makeParsedReminder(addressText: "  上海新国际博览中心  ")

        let reminder = try await fixture.store.create(from: parsed, scheduleNotification: false)

        XCTAssertEqual(reminder.addressText, "上海新国际博览中心")
    }

    func testUpdateCancelsExistingNotificationAndSchedulesUpdatedReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let updatedDate = Date().addingTimeInterval(1_200)

        try await fixture.store.update(
            reminder,
            title: "更新后的提醒",
            remindAt: updatedDate,
            repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil),
            tag: .waitingConfirmation,
            addressText: nil
        )

        XCTAssertEqual(reminder.title, "更新后的提醒")
        XCTAssertEqual(reminder.tag, .waitingConfirmation)
        XCTAssertEqual(reminder.remindAt, updatedDate)
        XCTAssertEqual(reminder.repeatRule.type, .daily)
        XCTAssertEqual(fixture.notificationService.canceledIds, [reminder.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testUpdateRollsBackReminderWhenSchedulingFails() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let originalTitle = reminder.title
        let originalTag = reminder.tag
        let originalDate = reminder.remindAt
        let originalRepeatRule = reminder.repeatRule
        fixture.notificationService.scheduleError = NotificationError.notAuthorized

        do {
            try await fixture.store.update(
                reminder,
                title: "更新后的提醒",
                remindAt: Date().addingTimeInterval(1_200),
                repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil),
                tag: .meetingCommunication,
                addressText: nil
            )
            XCTFail("Expected update to throw")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }

        XCTAssertEqual(reminder.title, originalTitle)
        XCTAssertEqual(reminder.tag, originalTag)
        XCTAssertEqual(reminder.remindAt, originalDate)
        XCTAssertEqual(reminder.repeatRule, originalRepeatRule)
    }

    func testUpdatePersistsTrimmedAddressText() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try await fixture.store.update(
            reminder,
            title: reminder.title,
            remindAt: reminder.remindAt,
            repeatRule: reminder.repeatRule,
            tag: reminder.tag,
            addressText: "  上海新国际博览中心  "
        )

        XCTAssertEqual(reminder.addressText, "上海新国际博览中心")
    }

    func testUpdateStoresBlankAddressAsNil() async throws {
        let fixture = try makeStoreFixture()
        let reminder = Reminder(
            title: "去展馆",
            rawInput: "明天去展馆",
            remindAt: Date().addingTimeInterval(600),
            addressText: "上海新国际博览中心"
        )
        fixture.container.mainContext.insert(reminder)
        try fixture.container.mainContext.save()

        try await fixture.store.update(
            reminder,
            title: reminder.title,
            remindAt: reminder.remindAt,
            repeatRule: reminder.repeatRule,
            tag: reminder.tag,
            addressText: "   "
        )

        XCTAssertNil(reminder.addressText)
    }

    func testUpdateRollsBackAddressTextWhenSchedulingFails() async throws {
        let fixture = try makeStoreFixture()
        let reminder = Reminder(
            title: "去展馆",
            rawInput: "明天去展馆",
            remindAt: Date().addingTimeInterval(600),
            addressText: "上海新国际博览中心"
        )
        fixture.container.mainContext.insert(reminder)
        try fixture.container.mainContext.save()
        fixture.notificationService.scheduleError = NotificationError.notAuthorized

        do {
            try await fixture.store.update(
                reminder,
                title: "去机场",
                remindAt: Date().addingTimeInterval(1_200),
                repeatRule: reminder.repeatRule,
                tag: reminder.tag,
                addressText: "上海虹桥机场"
            )
            XCTFail("Expected update to throw")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }

        XCTAssertEqual(reminder.title, "去展馆")
        XCTAssertEqual(reminder.addressText, "上海新国际博览中心")
    }

    func testTaskDetailViewModelAddressChangeEnablesSave() {
        let reminder = Reminder(
            title: "去展馆",
            rawInput: "明天去展馆",
            remindAt: Date().addingTimeInterval(600)
        )
        let viewModel = TaskDetailViewModel(reminder: reminder)

        viewModel.addressText = "  上海新国际博览中心  "

        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(viewModel.normalizedAddressText, "上海新国际博览中心")
    }

    func testConfirmReminderViewModelBuildsParsedReminderWithAddress() {
        var parsed = makeParsedReminder()
        parsed.addressText = nil
        let viewModel = ConfirmReminderViewModel(parsedReminder: parsed)

        viewModel.addressText = "  上海新国际博览中心  "
        let confirmed = viewModel.buildParsedReminder()

        XCTAssertEqual(confirmed.addressText, "上海新国际博览中心")
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

    func testRestoreDeletedReminderRemovesArchiveRecord() async throws {
        let deletedArchive = MockDeletedArchive()
        let fixture = try makeStoreFixture(deletedArchive: deletedArchive)
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let reminderId = reminder.id

        try fixture.store.delete(reminder)
        try await fixture.store.restore(reminder)

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertEqual(deletedArchive.appendedIds, [reminderId])
        XCTAssertEqual(deletedArchive.removedIds, [reminderId])
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

    func testRestoreCompletedReminderClearsCompletedAtAndSchedulesFutureReminder() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try await fixture.store.complete(reminder)
        XCTAssertEqual(reminder.status, .completed)
        XCTAssertNotNil(reminder.completedAt)

        try await fixture.store.restore(reminder)

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertNil(reminder.completedAt)
        XCTAssertEqual(fixture.notificationService.scheduledIds, [reminder.notificationId])
    }

    func testRestorePastCompletedReminderDoesNotScheduleNotification() async throws {
        let fixture = try makeStoreFixture()
        let pastDate = Date().addingTimeInterval(-600)
        let reminder = try await fixture.store.create(
            from: makeParsedReminder(datetime: pastDate),
            scheduleNotification: false
        )

        try await fixture.store.complete(reminder)
        try await fixture.store.restore(reminder, now: Date())

        XCTAssertEqual(reminder.status, .pending)
        XCTAssertNil(reminder.completedAt)
        XCTAssertTrue(fixture.notificationService.scheduledIds.isEmpty)
    }

    func testRestoreCompletedReminderRollsBackWhenSchedulingFails() async throws {
        let fixture = try makeStoreFixture()
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)

        try await fixture.store.complete(reminder)
        let completedAt = try XCTUnwrap(reminder.completedAt)
        fixture.notificationService.scheduleError = NotificationError.notAuthorized

        do {
            try await fixture.store.restore(reminder)
            XCTFail("Expected restore to throw")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }

        XCTAssertEqual(reminder.status, .completed)
        XCTAssertEqual(reminder.completedAt, completedAt)
        XCTAssertTrue(fixture.notificationService.scheduledIds.isEmpty)
    }

    func testPermanentlyDeleteRemovesDeletedReminderAndArchiveRecord() async throws {
        let deletedArchive = MockDeletedArchive()
        let fixture = try makeStoreFixture(deletedArchive: deletedArchive)
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let reminderId = reminder.id

        try fixture.store.delete(reminder)
        try fixture.store.permanentlyDelete(reminder)

        XCTAssertNil(try fixture.store.reminder(id: reminderId))
        XCTAssertEqual(deletedArchive.appendedIds, [reminderId])
        XCTAssertEqual(deletedArchive.removedIds, [reminderId])
    }

    func testPermanentlyDeleteMultipleDeletedRemindersRemovesArchiveRecords() async throws {
        let deletedArchive = MockDeletedArchive()
        let fixture = try makeStoreFixture(deletedArchive: deletedArchive)
        let firstReminder = try await fixture.store.create(
            from: makeParsedReminder(title: "删除第一条", rawInput: "删除第一条"),
            scheduleNotification: false
        )
        let secondReminder = try await fixture.store.create(
            from: makeParsedReminder(title: "删除第二条", rawInput: "删除第二条"),
            scheduleNotification: false
        )
        let firstId = firstReminder.id
        let secondId = secondReminder.id

        try fixture.store.delete(firstReminder)
        try fixture.store.delete(secondReminder)
        try fixture.store.permanentlyDelete([firstReminder, secondReminder])

        XCTAssertNil(try fixture.store.reminder(id: firstId))
        XCTAssertNil(try fixture.store.reminder(id: secondId))
        XCTAssertEqual(deletedArchive.appendedIds, [firstId, secondId])
        XCTAssertEqual(deletedArchive.removedBatches, [Set([firstId, secondId])])
        XCTAssertEqual(Set(deletedArchive.removedIds), Set([firstId, secondId]))
    }

    func testPermanentlyDeleteRemovesCompletedReminderWithoutArchiveRecord() async throws {
        let deletedArchive = MockDeletedArchive()
        let fixture = try makeStoreFixture(deletedArchive: deletedArchive)
        let reminder = try await fixture.store.create(from: makeParsedReminder(), scheduleNotification: false)
        let reminderId = reminder.id

        try await fixture.store.complete(reminder)
        try fixture.store.permanentlyDelete(reminder)

        XCTAssertNil(try fixture.store.reminder(id: reminderId))
        XCTAssertTrue(deletedArchive.appendedIds.isEmpty)
        XCTAssertTrue(deletedArchive.removedIds.isEmpty)
        XCTAssertTrue(deletedArchive.removedBatches.isEmpty)
    }

    func testPermanentlyDeleteMultipleCompletedRemindersWithoutArchiveRecords() async throws {
        let deletedArchive = MockDeletedArchive()
        let fixture = try makeStoreFixture(deletedArchive: deletedArchive)
        let firstReminder = try await fixture.store.create(
            from: makeParsedReminder(title: "完成第一条", rawInput: "完成第一条"),
            scheduleNotification: false
        )
        let secondReminder = try await fixture.store.create(
            from: makeParsedReminder(title: "完成第二条", rawInput: "完成第二条"),
            scheduleNotification: false
        )
        let firstId = firstReminder.id
        let secondId = secondReminder.id

        try await fixture.store.complete(firstReminder)
        try await fixture.store.complete(secondReminder)
        try fixture.store.permanentlyDelete([firstReminder, secondReminder])

        XCTAssertNil(try fixture.store.reminder(id: firstId))
        XCTAssertNil(try fixture.store.reminder(id: secondId))
        XCTAssertTrue(deletedArchive.appendedIds.isEmpty)
        XCTAssertTrue(deletedArchive.removedIds.isEmpty)
        XCTAssertTrue(deletedArchive.removedBatches.isEmpty)
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

    func testRefreshScheduledNotificationsReschedulesOnlyFutureActiveReminders() async throws {
        let fixture = try makeStoreFixture()
        let now = Date()
        let future = Reminder(
            title: "订外卖",
            rawInput: "上午11点提醒我订外卖",
            remindAt: now.addingTimeInterval(3_600)
        )
        let overdue = Reminder(
            title: "吃药",
            rawInput: "每天早上8点提醒我吃药",
            remindAt: now.addingTimeInterval(-600)
        )
        let completed = Reminder(
            title: "通知我睡觉",
            rawInput: "22点55提醒我睡觉",
            remindAt: now.addingTimeInterval(3_600),
            status: .completed
        )
        let deleted = Reminder(
            title: "做 SDK 的战略规划",
            rawInput: "明天上午提醒我做 SDK 的战略规划",
            remindAt: now.addingTimeInterval(3_600),
            status: .deleted
        )

        await fixture.store.refreshScheduledNotifications(
            for: [future, overdue, completed, deleted],
            now: now
        )

        XCTAssertEqual(fixture.notificationService.scheduledIds, [future.notificationId])
        XCTAssertEqual(fixture.notificationService.scheduledTitles, ["订外卖"])
    }

    func testShortcutCreationCreatesReminderAndSchedulesNotification() async throws {
        let fixture = try makeStoreFixture()
        let now = makeSearchDate(year: 2026, month: 6, day: 5, hour: 14)
        let service = makeShortcutCreationService(fixture: fixture, now: now)

        let result = await service.createReminder(from: "明天早上10点给客户打电话")
        let reminders = try fixture.container.mainContext.fetch(FetchDescriptor<Reminder>())

        XCTAssertEqual(result.status, .created)
        XCTAssertEqual(result.title, "给客户打电话")
        XCTAssertEqual(result.remindAt, makeSearchDate(year: 2026, month: 6, day: 6, hour: 10))
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "给客户打电话")
        XCTAssertEqual(fixture.notificationService.scheduledTitles, ["给客户打电话"])
    }

    func testShortcutCreationHandlesWeekdayTimeText() async throws {
        let fixture = try makeStoreFixture()
        let now = makeSearchDate(year: 2026, month: 6, day: 5, hour: 14)
        let service = makeShortcutCreationService(fixture: fixture, now: now)

        let result = await service.createReminder(from: "下周二下午4点打篮球")

        XCTAssertEqual(result.status, .created)
        XCTAssertEqual(result.title, "打篮球")
        XCTAssertEqual(result.remindAt, makeSearchDate(year: 2026, month: 6, day: 9, hour: 16))
        XCTAssertEqual(fixture.notificationService.scheduledTitles, ["打篮球"])
    }

    func testShortcutCreationRequiresNotificationPermission() async throws {
        let fixture = try makeStoreFixture()
        fixture.notificationService.status = .denied
        let service = makeShortcutCreationService(fixture: fixture)

        let result = await service.createReminder(from: "明天早上10点给客户打电话")
        let reminders = try fixture.container.mainContext.fetch(FetchDescriptor<Reminder>())

        XCTAssertEqual(result.status, .notificationPermissionRequired)
        XCTAssertEqual(result.dialog, "还没有开启通知权限，请先打开一句话提醒开启通知。")
        XCTAssertTrue(reminders.isEmpty)
        XCTAssertTrue(fixture.notificationService.scheduledTitles.isEmpty)
    }

    func testShortcutCreationRequiresMembership() async throws {
        let fixture = try makeStoreFixture()
        let service = makeShortcutCreationService(fixture: fixture, membershipStatus: .free)

        let result = await service.createReminder(from: "明天早上10点给客户打电话")
        let reminders = try fixture.container.mainContext.fetch(FetchDescriptor<Reminder>())

        XCTAssertEqual(result.status, .membershipRequired)
        XCTAssertEqual(result.dialog, "Siri / 快捷指令创建提醒是 Pro 权益，请先打开一句话提醒升级 Pro。")
        XCTAssertTrue(reminders.isEmpty)
        XCTAssertTrue(fixture.notificationService.scheduledTitles.isEmpty)
    }

    func testShortcutCreationDoesNotCreateIncompleteReminder() async throws {
        let fixture = try makeStoreFixture()
        let service = makeShortcutCreationService(fixture: fixture)

        let result = await service.createReminder(from: "提醒我给客户打电话")
        let reminders = try fixture.container.mainContext.fetch(FetchDescriptor<Reminder>())

        XCTAssertEqual(result.status, .needsMoreInfo)
        XCTAssertEqual(result.dialog, "请说清楚提醒时间。")
        XCTAssertTrue(reminders.isEmpty)
        XCTAssertTrue(fixture.notificationService.scheduledTitles.isEmpty)
    }

    func testKeywordMatcherBlankKeywordMatchesReminder() {
        let reminder = makeReminderForSearch(title: "去上海", rawInput: "下个月去上海")

        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "   "))
    }

    func testKeywordMatcherMatchesTitleAndRawInput() {
        let reminder = makeReminderForSearch(title: "去上海", rawInput: "下个月12号下午5点去上海")

        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "上海"))
        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "下午5点"))
        XCTAssertFalse(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "客户"))
    }

    func testKeywordMatcherMatchesTagName() {
        let reminder = makeReminderForSearch(title: "约时间", rawInput: "下周一约下客户时间", tag: .waitingConfirmation)

        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "等待确认"))
        XCTAssertFalse(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "娱乐休闲"))
    }

    func testLegacyReminderWithoutTagDefaultsToOther() {
        let reminder = Reminder(title: "整理桌面", rawInput: "明天整理桌面", remindAt: Date())

        XCTAssertEqual(reminder.tag, .other)
    }

    func testKeywordMatcherRequiresAllTokensToMatch() {
        let reminder = makeReminderForSearch(title: "给客户打电话", rawInput: "后天上午给客户打电话")

        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "客户 电话"))
        XCTAssertFalse(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "客户 上海"))
    }

    func testKeywordMatcherMatchesReminderDateAndActionDate() {
        let reminder = makeReminderForSearch(
            title: "去上海",
            rawInput: "下个月12号下午5点去上海",
            remindAt: makeSearchDate(year: 2026, month: 7, day: 12, hour: 17)
        )
        let completedAt = makeSearchDate(year: 2026, month: 6, day: 3, hour: 12)

        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "7月12日", actionDate: completedAt))
        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "6月3日", actionDate: completedAt))
        XCTAssertTrue(ReminderKeywordMatcher.matches(reminder: reminder, keyword: "17:00", actionDate: completedAt))
    }

    func testMapNavigationServiceFiltersUnavailableMapApps() {
        let service = MapNavigationService { url in
            url.scheme == "baidumap"
        }

        let options = service.availableOptions(for: "上海新国际博览中心")

        XCTAssertEqual(options.map(\.provider), [.baidu])
    }

    func testMapNavigationServiceIncludesGoogleMapsWhenInstalled() {
        let service = MapNavigationService { url in
            ["maps", "iosamap", "baidumap", "qqmap", "comgooglemaps"].contains(url.scheme)
        }

        let options = service.availableOptions(for: "香港国际机场")

        XCTAssertEqual(options.map(\.provider), [.appleMaps, .amap, .baidu, .tencent, .google])
    }

    func testMapNavigationServiceReturnsNoOptionsForBlankAddress() {
        let service = MapNavigationService { _ in true }

        XCTAssertTrue(service.availableOptions(for: "   ").isEmpty)
    }

    func testMapNavigationServiceBuildsURLWithEncodedChineseAddress() throws {
        let service = MapNavigationService { _ in true }
        let url = try XCTUnwrap(
            service.navigationURL(for: .baidu, address: "  上海新国际博览中心  ")
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let destination = components.queryItems?.first { $0.name == "destination" }?.value

        XCTAssertEqual(url.scheme, "baidumap")
        XCTAssertFalse(url.absoluteString.contains(" "))
        XCTAssertEqual(destination, "上海新国际博览中心")
    }

    func testMapNavigationServiceBuildsGoogleMapsURL() throws {
        let service = MapNavigationService { _ in true }
        let url = try XCTUnwrap(
            service.navigationURL(for: .google, address: "  香港国际机场  ")
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let destination = components.queryItems?.first { $0.name == "daddr" }?.value
        let directionsMode = components.queryItems?.first { $0.name == "directionsmode" }?.value

        XCTAssertEqual(url.scheme, "comgooglemaps")
        XCTAssertFalse(url.absoluteString.contains(" "))
        XCTAssertEqual(destination, "香港国际机场")
        XCTAssertEqual(directionsMode, "driving")
    }

    func testMigratesReminderStoreFromSchemaV1ToV3() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReminderMigration-\(UUID().uuidString).store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        let oldSchema = Schema(versionedSchema: ReminderSchemaV1.self)
        let oldContainer = try ModelContainer(
            for: oldSchema,
            configurations: ModelConfiguration(url: storeURL)
        )
        let oldReminder = ReminderSchemaV1.Reminder(
            title: "旧数据提醒",
            rawInput: "明天提醒我旧数据",
            remindAt: makeSearchDate(year: 2026, month: 6, day: 9, hour: 10)
        )
        oldContainer.mainContext.insert(oldReminder)
        try oldContainer.mainContext.save()

        let newSchema = Schema(versionedSchema: ReminderSchemaV3.self)
        let migratedContainer = try ModelContainer(
            for: newSchema,
            migrationPlan: ReminderMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let migrated = try migratedContainer.mainContext.fetch(FetchDescriptor<Reminder>())

        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated.first?.title, "旧数据提醒")
        XCTAssertEqual(migrated.first?.tag, .other)
        XCTAssertNil(migrated.first?.addressText)
    }

    private func makeStoreFixture() throws -> (
        container: ModelContainer,
        notificationService: MockNotificationService,
        store: ReminderStore
    ) {
        try makeStoreFixture(deletedArchive: nil)
    }

    private func makeStoreFixture(deletedArchive: DeletedReminderArchiving?) throws -> (
        container: ModelContainer,
        notificationService: MockNotificationService,
        store: ReminderStore
    ) {
        let container = try ModelContainer(
            for: Reminder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let notificationService = MockNotificationService()
        let store = ReminderStore(
            context: container.mainContext,
            notificationService: notificationService,
            deletedArchive: deletedArchive
        )
        return (container, notificationService, store)
    }

    private func makeParsedReminder(
        title: String = "取快递",
        datetime: Date = Date().addingTimeInterval(600),
        repeatRule: RepeatRule? = nil,
        rawInput: String = "10分钟后提醒我取快递",
        tag: ReminderTag = .dailyLife,
        addressText: String? = nil
    ) -> ParsedReminder {
        ParsedReminder(
            title: title,
            tag: tag,
            addressText: addressText,
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

    private func makeReminderForSearch(
        title: String,
        rawInput: String,
        remindAt: Date = Date(),
        tag: ReminderTag? = nil
    ) -> Reminder {
        Reminder(title: title, rawInput: rawInput, remindAt: remindAt, tag: tag)
    }

    private func makeSearchDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hans-CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeShortcutCreationService(
        fixture: (
            container: ModelContainer,
            notificationService: MockNotificationService,
            store: ReminderStore
        ),
        now: Date = Date(),
        membershipStatus: MembershipStatus = .active
    ) -> ShortcutReminderCreationService {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hans-CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return ShortcutReminderCreationService(
            container: fixture.container,
            notificationService: fixture.notificationService,
            membershipStorage: MockMembershipEntitlementStorage(status: membershipStatus),
            now: { now },
            calendar: calendar,
            settings: .default
        )
    }
}

private final class MockNotificationService: NotificationScheduling {
    var scheduledIds: [String] = []
    var scheduledTitles: [String] = []
    var canceledIds: [String] = []
    var scheduleError: Error?
    var status: UNAuthorizationStatus = .authorized

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func schedule(reminder: Reminder) async throws {
        if let scheduleError {
            throw scheduleError
        }
        scheduledIds.append(reminder.notificationId)
        scheduledTitles.append(reminder.title)
    }

    func cancel(notificationId: String) {
        canceledIds.append(notificationId)
    }
}

private final class MockMembershipEntitlementStorage: MembershipEntitlementStoring {
    private var entitlement: MembershipEntitlement?

    init(status: MembershipStatus) {
        entitlement = MembershipEntitlement(
            userID: "usr_test",
            productID: status == .free ? nil : SubscriptionPlan.monthly.productID,
            originalTransactionID: status == .free ? nil : "txn_test",
            membershipStatus: status,
            expiresAt: status == .free ? nil : Date().addingTimeInterval(86_400),
            trialUsed: false,
            autoRenewStatus: status == .free ? nil : true,
            updatedAt: Date()
        )
    }

    func loadEntitlement() -> MembershipEntitlement? {
        entitlement
    }

    func save(entitlement: MembershipEntitlement) {
        self.entitlement = entitlement
    }

    func clear() {
        entitlement = nil
    }
}

private final class MockDeletedArchive: DeletedReminderArchiving {
    var appendedIds: [UUID] = []
    var removedIds: [UUID] = []
    var removedBatches: [Set<UUID>] = []

    func append(reminder: Reminder, deletedAt: Date) throws {
        appendedIds.append(reminder.id)
    }

    func removeRecord(id: UUID) throws {
        removedIds.append(id)
    }

    func removeRecords(ids: Set<UUID>) throws {
        removedBatches.append(ids)
        removedIds.append(contentsOf: ids)
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

    func testNotificationContentUsesReminderTitleAsVisibleTitle() throws {
        let reminder = Reminder(
            title: "给客户打电话",
            rawInput: "明天下午3点提醒我给客户打电话",
            remindAt: try date("2026-05-25T15:00:00+08:00"),
            repeatRule: RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
        )

        let content = NotificationService.makeContent(for: reminder, calendar: calendar)

        XCTAssertEqual(content.title, "给客户打电话")
        XCTAssertEqual(content.subtitle, "")
        XCTAssertTrue(content.body.contains("每天"))
        XCTAssertEqual(content.categoryIdentifier, NotificationActionIdentifier.category)
        XCTAssertTrue(content.threadIdentifier.isEmpty)
        XCTAssertEqual(content.userInfo["reminderId"] as? String, reminder.id.uuidString)
    }

    func testNotificationContentUsesConcreteTaskForTakeoutReminder() throws {
        let reminder = Reminder(
            title: "订外卖",
            rawInput: "上午11点提醒我订外卖",
            remindAt: try date("2026-05-25T11:00:00+08:00")
        )

        let content = NotificationService.makeContent(for: reminder, calendar: calendar)

        XCTAssertEqual(content.title, "订外卖")
        XCTAssertEqual(content.subtitle, "")
        XCTAssertTrue(content.body.contains("11:00"))
    }

    func testNotificationContentFallsBackWhenReminderTitleIsBlank() throws {
        let reminder = Reminder(
            title: "   ",
            rawInput: "明天下午3点提醒我",
            remindAt: try date("2026-05-25T15:00:00+08:00")
        )

        let content = NotificationService.makeContent(for: reminder, calendar: calendar)

        XCTAssertEqual(content.title, "提醒时间到了")
        XCTAssertFalse(content.body.isEmpty)
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

    func testBiweeklyRepeatUsesOneTimeTriggerAtCurrentReminderDate() throws {
        let reminder = Reminder(
            title: "双周会议",
            rawInput: "SDK 媒介双周会议",
            remindAt: try date("2026-06-15T10:00:00+08:00"),
            repeatRule: RepeatRule(type: .weekly, interval: 2, weekday: nil, dayOfMonth: nil)
        )

        let trigger = try calendarTrigger(for: reminder)
        let content = NotificationService.makeContent(for: reminder, calendar: calendar)

        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.year, 2026)
        XCTAssertEqual(trigger.dateComponents.month, 6)
        XCTAssertEqual(trigger.dateComponents.day, 15)
        XCTAssertEqual(trigger.dateComponents.hour, 10)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(content.body.contains("每双周"))
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
