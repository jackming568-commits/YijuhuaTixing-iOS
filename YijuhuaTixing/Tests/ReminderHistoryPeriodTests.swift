import XCTest
@testable import YijuhuaTixing

final class ReminderHistoryPeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    func testHistoryPeriodsUseOperationTimeAndNearestSingleBucket() throws {
        let now = try date("2026-06-24T12:00:00+08:00")

        XCTAssertEqual(try period("2026-06-24T09:00:00+08:00", now: now), .today)
        XCTAssertEqual(try period("2026-06-22T09:00:00+08:00", now: now), .thisWeek)
        XCTAssertEqual(try period("2026-06-10T09:00:00+08:00", now: now), .thisMonth)
        XCTAssertEqual(try period("2026-05-15T09:00:00+08:00", now: now), .thisQuarter)
        XCTAssertEqual(try period("2026-02-01T09:00:00+08:00", now: now), .thisHalfYear)
        XCTAssertEqual(try period("2025-02-01T09:00:00+08:00", now: now), .twoYears)
        XCTAssertEqual(try period("2024-02-01T09:00:00+08:00", now: now), .threeYears)
        XCTAssertEqual(try period("2023-02-01T09:00:00+08:00", now: now), .fiveYears)
        XCTAssertEqual(try period("2022-02-01T09:00:00+08:00", now: now), .fiveYears)
    }

    func testHistoryPeriodsUseNaturalYearAfterCurrentHalfYear() throws {
        let now = try date("2026-10-24T12:00:00+08:00")

        XCTAssertEqual(try period("2026-06-30T09:00:00+08:00", now: now), .thisYear)
    }

    func testHistoryPeriodFiltersFutureAndOlderThanFiveYears() throws {
        let now = try date("2026-06-24T12:00:00+08:00")

        XCTAssertNil(try period("2026-06-25T09:00:00+08:00", now: now))
        XCTAssertEqual(try period("2022-01-01T00:00:00+08:00", now: now), .fiveYears)
        XCTAssertNil(try period("2021-12-31T23:59:00+08:00", now: now))
    }

    private func period(_ string: String, now: Date) throws -> ReminderHistoryPeriod? {
        try ReminderHistoryPeriod.period(for: date(string), now: now, calendar: calendar)
    }

    private func date(_ string: String) throws -> Date {
        guard let date = ISO8601DateFormatter.yijuhuaHistoryPeriod.date(from: string) else {
            throw TestError.badDate
        }
        return date
    }
}

private enum TestError: Error {
    case badDate
}

private extension ISO8601DateFormatter {
    static let yijuhuaHistoryPeriod: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
