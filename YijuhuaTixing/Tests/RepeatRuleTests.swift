import XCTest
@testable import YijuhuaTixing

final class RepeatRuleTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    func testDailyRepeat() throws {
        let start = try date("2026-05-24T08:00:00+08:00")
        let next = RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
            .nextDate(after: start, calendar: calendar)
        XCTAssertEqual(next, try date("2026-05-25T08:00:00+08:00"))
    }

    func testHourlyRepeatUsesInterval() throws {
        let start = try date("2026-05-24T18:00:00+08:00")
        let next = RepeatRule(type: .hourly, interval: 2, weekday: nil, dayOfMonth: nil)
            .nextDate(after: start, calendar: calendar)
        XCTAssertEqual(next, try date("2026-05-24T20:00:00+08:00"))
    }

    func testWeekdayRepeatSkipsSunday() throws {
        let start = try date("2026-05-24T09:00:00+08:00")
        let next = RepeatRule(type: .weekdays, interval: 1, weekday: nil, dayOfMonth: nil)
            .nextDate(after: start, calendar: calendar)
        XCTAssertEqual(next, try date("2026-05-25T09:00:00+08:00"))
    }

    func testWeekdayRepeatSkipsWeekendFromFriday() throws {
        let start = try date("2026-05-29T18:00:00+08:00")
        let next = RepeatRule(type: .weekdays, interval: 1, weekday: nil, dayOfMonth: nil)
            .nextDate(after: start, calendar: calendar)
        XCTAssertEqual(next, try date("2026-06-01T18:00:00+08:00"))
    }

    func testMonthlyRepeatHandlesNextMonth() throws {
        let start = try date("2026-05-30T20:00:00+08:00")
        let next = RepeatRule(type: .monthly, interval: 1, weekday: nil, dayOfMonth: 30)
            .nextDate(after: start, calendar: calendar)
        XCTAssertEqual(next, try date("2026-06-30T20:00:00+08:00"))
    }

    private func date(_ string: String) throws -> Date {
        guard let date = ISO8601DateFormatter.yijuhua.date(from: string) else {
            throw TestError.badDate
        }
        return date
    }
}

private enum TestError: Error {
    case badDate
}

private extension ISO8601DateFormatter {
    static let yijuhua: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
