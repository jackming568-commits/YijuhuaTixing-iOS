import XCTest
@testable import YijuhuaTixing

final class ReminderArchivePeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    func testArchivePeriodsUseNearestNaturalCalendarBuckets() throws {
        let now = try date("2026-06-03T12:00:00+08:00")

        XCTAssertEqual(try period("2026-06-03T20:00:00+08:00", now: now), .today)
        XCTAssertEqual(try period("2026-06-05T09:00:00+08:00", now: now), .thisWeek)
        XCTAssertEqual(try period("2026-06-08T09:00:00+08:00", now: now), .nextWeek)
        XCTAssertEqual(try period("2026-06-20T09:00:00+08:00", now: now), .thisMonth)
        XCTAssertEqual(try period("2026-07-03T09:00:00+08:00", now: now), .nextMonth)
        XCTAssertEqual(try period("2026-12-15T09:00:00+08:00", now: now), .thisYear)
        XCTAssertEqual(try period("2027-07-01T09:00:00+08:00", now: now), .twoYears)
        XCTAssertEqual(try period("2028-07-01T09:00:00+08:00", now: now), .threeYears)
        XCTAssertEqual(try period("2029-07-01T09:00:00+08:00", now: now), .fourYears)
        XCTAssertEqual(try period("2030-07-01T09:00:00+08:00", now: now), .fiveYears)
        XCTAssertEqual(try period("2031-01-01T00:00:00+08:00", now: now), .beyondFiveYears)
    }

    func testArchivePeriodsUseNaturalQuarterAndHalfYearBoundaries() throws {
        XCTAssertEqual(
            try period("2026-06-20T09:00:00+08:00", now: try date("2026-04-10T12:00:00+08:00")),
            .thisQuarter
        )
        XCTAssertEqual(
            try period("2026-04-20T09:00:00+08:00", now: try date("2026-02-10T12:00:00+08:00")),
            .thisHalfYear
        )
    }

    func testArchivePeriodsPrioritizeNearBucketsAcrossYearBoundary() throws {
        let now = try date("2026-12-28T12:00:00+08:00")

        XCTAssertEqual(try period("2026-12-31T09:00:00+08:00", now: now), .thisWeek)
        XCTAssertEqual(try period("2027-01-03T09:00:00+08:00", now: now), .thisWeek)
        XCTAssertEqual(try period("2027-01-05T09:00:00+08:00", now: now), .nextWeek)
        XCTAssertEqual(try period("2027-01-11T09:00:00+08:00", now: now), .nextMonth)
        XCTAssertEqual(try period("2027-01-31T09:00:00+08:00", now: now), .nextMonth)
        XCTAssertEqual(try period("2027-02-01T09:00:00+08:00", now: now), .twoYears)
    }

    func testReminderFlowsIntoNearestSinglePeriodAsDateApproaches() throws {
        let target = try date("2026-06-20T09:00:00+08:00")

        XCTAssertEqual(try period(for: target, now: "2026-02-10T12:00:00+08:00"), .thisHalfYear)
        XCTAssertEqual(try period(for: target, now: "2026-04-10T12:00:00+08:00"), .thisQuarter)
        XCTAssertEqual(try period(for: target, now: "2026-05-10T12:00:00+08:00"), .nextMonth)
        XCTAssertEqual(try period(for: target, now: "2026-06-01T12:00:00+08:00"), .thisMonth)
        XCTAssertEqual(try period(for: target, now: "2026-06-08T12:00:00+08:00"), .nextWeek)
        XCTAssertEqual(try period(for: target, now: "2026-06-15T12:00:00+08:00"), .thisWeek)
        XCTAssertEqual(try period(for: target, now: "2026-06-20T00:01:00+08:00"), .today)
    }

    func testOverduePeriodIsOnlyUsedWhenRequested() throws {
        let now = try date("2026-06-03T12:00:00+08:00")
        let yesterday = try date("2026-06-02T12:00:00+08:00")

        XCTAssertEqual(
            ReminderArchivePeriod.period(for: yesterday, now: now, calendar: calendar, includeOverdue: true),
            .overdue
        )
        XCTAssertEqual(
            ReminderArchivePeriod.period(for: yesterday, now: now, calendar: calendar, includeOverdue: false),
            .thisWeek
        )
    }

    private func period(_ string: String, now: Date) throws -> ReminderArchivePeriod {
        try ReminderArchivePeriod.period(for: date(string), now: now, calendar: calendar)
    }

    private func period(for target: Date, now: String) throws -> ReminderArchivePeriod {
        ReminderArchivePeriod.period(for: target, now: try date(now), calendar: calendar)
    }

    private func date(_ string: String) throws -> Date {
        guard let date = ISO8601DateFormatter.yijuhuaArchivePeriod.date(from: string) else {
            throw TestError.badDate
        }
        return date
    }
}

private enum TestError: Error {
    case badDate
}

private extension ISO8601DateFormatter {
    static let yijuhuaArchivePeriod: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
