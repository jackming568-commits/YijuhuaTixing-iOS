import XCTest
@testable import YijuhuaTixing

@MainActor
final class MembershipGateTests: XCTestCase {
    func testFreeDailyLimitAllowsFewerThanThreeCreations() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = [
            makeReminder(createdAt: makeDate(day: 5, hour: 8)),
            makeReminder(createdAt: makeDate(day: 5, hour: 9))
        ]

        XCTAssertEqual(MembershipGate.createdTodayCount(reminders: reminders, now: now, calendar: calendar), 2)
        XCTAssertTrue(MembershipGate.canCreateReminder(hasProAccess: false, reminders: reminders, now: now, calendar: calendar, bypassDebugLimit: false))
    }

    func testFreeDailyLimitBlocksFourthCreation() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = [
            makeReminder(createdAt: makeDate(day: 5, hour: 8)),
            makeReminder(createdAt: makeDate(day: 5, hour: 9)),
            makeReminder(createdAt: makeDate(day: 5, hour: 10))
        ]

        XCTAssertEqual(MembershipGate.createdTodayCount(reminders: reminders, now: now, calendar: calendar), 3)
        XCTAssertFalse(MembershipGate.canCreateReminder(hasProAccess: false, reminders: reminders, now: now, calendar: calendar, bypassDebugLimit: false))
    }

    func testProAccessBypassesDailyLimit() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = (0..<6).map { hour in
            makeReminder(createdAt: makeDate(day: 5, hour: hour + 6))
        }

        XCTAssertTrue(MembershipGate.canCreateReminder(hasProAccess: true, reminders: reminders, now: now, calendar: calendar, bypassDebugLimit: false))
    }

    func testCreatedTodayCountIgnoresOtherDays() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = [
            makeReminder(createdAt: makeDate(day: 4, hour: 23)),
            makeReminder(createdAt: makeDate(day: 5, hour: 0)),
            makeReminder(createdAt: makeDate(day: 6, hour: 1))
        ]

        XCTAssertEqual(MembershipGate.createdTodayCount(reminders: reminders, now: now, calendar: calendar), 1)
    }

    func testDailyLimitCountsCompletedAndDeletedReminders() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = [
            makeReminder(createdAt: makeDate(day: 5, hour: 8), status: .pending),
            makeReminder(createdAt: makeDate(day: 5, hour: 9), status: .completed),
            makeReminder(createdAt: makeDate(day: 5, hour: 10), status: .deleted)
        ]

        XCTAssertEqual(MembershipGate.createdTodayCount(reminders: reminders, now: now, calendar: calendar), 3)
        XCTAssertFalse(MembershipGate.canCreateReminder(hasProAccess: false, reminders: reminders, now: now, calendar: calendar, bypassDebugLimit: false))
    }

    func testDebugBuildBypassesFreeDailyLimitForLocalTesting() {
        let now = makeDate(day: 5, hour: 12)
        let reminders = (0..<6).map { hour in
            makeReminder(createdAt: makeDate(day: 5, hour: hour + 6))
        }

        XCTAssertTrue(MembershipGate.canCreateReminder(hasProAccess: false, reminders: reminders, now: now, calendar: calendar, bypassDebugLimit: true))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: day,
            hour: hour
        ).date ?? Date(timeIntervalSince1970: 0)
    }

    private func makeReminder(createdAt: Date, status: ReminderStatus = .pending) -> Reminder {
        Reminder(
            title: "测试提醒",
            rawInput: "测试提醒",
            remindAt: createdAt.addingTimeInterval(3_600),
            status: status,
            createdAt: createdAt,
            updatedAt: createdAt,
            completedAt: status == .completed ? createdAt : nil
        )
    }
}
