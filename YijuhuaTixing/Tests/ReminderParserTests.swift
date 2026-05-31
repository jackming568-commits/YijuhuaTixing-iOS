import XCTest
@testable import YijuhuaTixing

final class ReminderParserTests: XCTestCase {
    private var parser: LocalReminderParser!
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        parser = LocalReminderParser()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        now = ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:00:00+08:00")!
    }

    func testParsesClearDateTime() throws {
        let parsed = try parseSuccess("明天上午10点提醒我给客户发报价")
        XCTAssertEqual(parsed.title, "给客户发报价")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T10:00:00+08:00"))
        XCTAssertEqual(parsed.confidence, 0.95, accuracy: 0.01)
    }

    func testParsesRelativeTime() throws {
        let parsed = try parseSuccess("30分钟后提醒我取快递")
        XCTAssertEqual(parsed.title, "取快递")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:30:00+08:00"))
    }

    func testParsesChineseNumberRelativeTime() throws {
        let oneMinute = try parseSuccess("一分钟后提醒我喝水")
        XCTAssertEqual(oneMinute.title, "喝水")
        XCTAssertEqual(oneMinute.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:01:00+08:00"))

        let fifteenMinutes = try parseSuccess("十五分钟后提醒我出门")
        XCTAssertEqual(fifteenMinutes.title, "出门")
        XCTAssertEqual(fifteenMinutes.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:15:00+08:00"))

        let missingTitle = try parseNeedsInput("一分钟后提醒我")
        XCTAssertEqual(missingTitle.title, "")
        XCTAssertEqual(missingTitle.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:01:00+08:00"))
        XCTAssertEqual(missingTitle.missingFields, [.title])
    }

    func testParsesCommonRelativeAndFuzzyTimePhrases() throws {
        let halfHour = try parseSuccess("半小时后提醒我喝水")
        XCTAssertEqual(halfHour.title, "喝水")
        XCTAssertEqual(halfHour.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T16:30:00+08:00"))

        let twoHours = try parseSuccess("两小时后提醒我开会")
        XCTAssertEqual(twoHours.title, "开会")
        XCTAssertEqual(twoHours.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T18:00:00+08:00"))

        let oneAndHalfHours = try parseSuccess("一个半小时后提醒我取衣服")
        XCTAssertEqual(oneAndHalfHours.title, "取衣服")
        XCTAssertEqual(oneAndHalfHours.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T17:30:00+08:00"))

        let twoAndHalfHours = try parseSuccess("两个半小时后提醒我出门")
        XCTAssertEqual(twoAndHalfHours.title, "出门")
        XCTAssertEqual(twoAndHalfHours.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T18:30:00+08:00"))

        let tonight = try parseSuccess("今晚提醒我整理账单")
        XCTAssertEqual(tonight.title, "整理账单")
        XCTAssertEqual(tonight.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T20:00:00+08:00"))

        let tomorrowMorning = try parseSuccess("明早提醒我带伞")
        XCTAssertEqual(tomorrowMorning.title, "带伞")
        XCTAssertEqual(tomorrowMorning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T09:00:00+08:00"))

        let tomorrowNight = try parseSuccess("明晚八点半提醒我给家里打电话")
        XCTAssertEqual(tomorrowNight.title, "给家里打电话")
        XCTAssertEqual(tomorrowNight.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T20:30:00+08:00"))

        let dayAfterTomorrowAfternoon = try parseSuccess("后天下午提醒我寄合同")
        XCTAssertEqual(dayAfterTomorrowAfternoon.title, "寄合同")
        XCTAssertEqual(dayAfterTomorrowAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-26T15:00:00+08:00"))

        let fridayAfternoon = try parseSuccess("周五下午提醒我复盘")
        XCTAssertEqual(fridayAfternoon.title, "复盘")
        XCTAssertEqual(fridayAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-29T15:00:00+08:00"))
    }

    func testParsesNextWeekdayAsNextCalendarWeek() throws {
        let tuesday = ISO8601DateFormatter.yijuhua.date(from: "2026-05-26T09:00:00+08:00")!

        let nextFriday = try parseSuccess("下周五下午3点提醒我复盘", now: tuesday)
        XCTAssertEqual(nextFriday.title, "复盘")
        XCTAssertEqual(nextFriday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-05T15:00:00+08:00"))

        let nextFridayAlt = try parseSuccess("下星期五下午3点提醒我复盘", now: tuesday)
        XCTAssertEqual(nextFridayAlt.title, "复盘")
        XCTAssertEqual(nextFridayAlt.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-05T15:00:00+08:00"))

        let thisFriday = try parseSuccess("这周五下午3点提醒我复盘", now: tuesday)
        XCTAssertEqual(thisFriday.title, "复盘")
        XCTAssertEqual(thisFriday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-29T15:00:00+08:00"))
    }

    func testParsesEndOfMonthAndWeekend() throws {
        let endOfMonth = try parseSuccess("月底提醒我交材料")
        XCTAssertEqual(endOfMonth.title, "交材料")
        XCTAssertEqual(endOfMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-31T09:00:00+08:00"))

        let endOfNextMonth = try parseSuccess("下个月底提醒我交房租")
        XCTAssertEqual(endOfNextMonth.title, "交房租")
        XCTAssertEqual(endOfNextMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-30T09:00:00+08:00"))

        let tuesday = ISO8601DateFormatter.yijuhua.date(from: "2026-05-26T09:00:00+08:00")!
        let weekend = try parseSuccess("周末提醒我露营", now: tuesday)
        XCTAssertEqual(weekend.title, "露营")
        XCTAssertEqual(weekend.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-30T09:00:00+08:00"))

        let thisWeekend = try parseSuccess("本周末提醒我整理房间", now: tuesday)
        XCTAssertEqual(thisWeekend.title, "整理房间")
        XCTAssertEqual(thisWeekend.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-30T09:00:00+08:00"))

        let thisWeekendSundayAfternoon = try parseSuccess("本周末提醒我整理房间")
        XCTAssertEqual(thisWeekendSundayAfternoon.title, "整理房间")
        XCTAssertEqual(thisWeekendSundayAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T20:00:00+08:00"))

        let sundayEvening = try parseSuccess("周日晚上提醒我给妈妈打电话")
        XCTAssertEqual(sundayEvening.title, "给妈妈打电话")
        XCTAssertEqual(sundayEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T20:00:00+08:00"))

        let weekendEvening = try parseSuccess("周末晚上提醒我看电影")
        XCTAssertEqual(weekendEvening.title, "看电影")
        XCTAssertEqual(weekendEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T20:00:00+08:00"))
    }

    func testUsesCustomDefaultTimeSettings() throws {
        var settings = ParserSettings.default
        settings.morningDefaultHour = 8
        settings.eveningDefaultHour = 21

        let morning = try parseSuccess("明早提醒我带伞", settings: settings)
        XCTAssertEqual(morning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))

        let evening = try parseSuccess("今晚提醒我整理账单", settings: settings)
        XCTAssertEqual(evening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T21:00:00+08:00"))
    }

    func testNeedsInputForVagueLater() throws {
        let parsed = try parseNeedsInput("晚点提醒我回消息")
        XCTAssertEqual(parsed.title, "回消息")
        XCTAssertTrue(parsed.missingFields.contains(.time))

        let later = try parseNeedsInput("稍后提醒")
        XCTAssertEqual(later.title, "")
        XCTAssertTrue(later.missingFields.contains(.title))
        XCTAssertTrue(later.missingFields.contains(.time))
    }

    func testParsesEveryTwoHoursRepeat() throws {
        let parsed = try parseSuccess("每隔两小时提醒我喝水")
        XCTAssertEqual(parsed.title, "喝水")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T18:00:00+08:00"))
        XCTAssertEqual(parsed.repeatRule?.type, .hourly)
        XCTAssertEqual(parsed.repeatRule?.interval, 2)
    }

    func testNeedsInputForContextualTimePhrases() throws {
        let afterWork = try parseNeedsInput("明天下班前提醒我交材料")
        XCTAssertEqual(afterWork.title, "交材料")
        XCTAssertEqual(afterWork.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T09:00:00+08:00"))
        XCTAssertEqual(afterWork.missingFields, [.time])
        XCTAssertEqual(afterWork.suggestions, ["当天早上", "当天下午", "当天晚上", "自定义时间"])

        let beforeSleep = try parseNeedsInput("提醒我睡前读书")
        XCTAssertEqual(beforeSleep.title, "读书")
        XCTAssertNil(beforeSleep.datetime)
        XCTAssertEqual(beforeSleep.missingFields, [.time])

        let afterMeal = try parseNeedsInput("饭后提醒我吃药")
        XCTAssertEqual(afterMeal.title, "吃药")
        XCTAssertNil(afterMeal.datetime)
        XCTAssertEqual(afterMeal.missingFields, [.time])
        XCTAssertEqual(afterMeal.suggestions, ["10分钟后", "30分钟后", "1小时后", "明天早上", "自定义时间"])
    }

    func testConfirmViewModelKeepsDateAnchorWhenOnlyTimeIsMissing() throws {
        let parsed = try parseNeedsInput("明天下班前提醒我交材料")
        let viewModel = ConfirmReminderViewModel(parsedReminder: parsed)

        XCTAssertEqual(viewModel.title, "交材料")
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T09:00:00+08:00"))
        XCTAssertEqual(viewModel.timeSummary, "请选择时间")
        XCTAssertFalse(viewModel.canConfirm)

        XCTAssertFalse(viewModel.applySuggestion("自定义时间"))
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T09:00:00+08:00"))
        XCTAssertFalse(viewModel.didAdjustTime)

        XCTAssertTrue(viewModel.applySuggestion("当天晚上"))
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T20:00:00+08:00"))
        XCTAssertTrue(viewModel.timeSummary.hasSuffix("20:00"))
    }

    func testDoesNotCreatePastReminder() throws {
        let parsed = try parseNeedsInput("今天上午10点提醒我给客户发报价")
        XCTAssertTrue(parsed.missingFields.contains(.validFutureTime))
    }

    func testParsesDailyRepeatToNextValidOccurrence() throws {
        let parsed = try parseSuccess("每天早上8点提醒我吃药")
        XCTAssertEqual(parsed.repeatRule?.type, .daily)
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))
    }

    func testParsesDailyRepeatWithFuzzyEvening() throws {
        let parsed = try parseSuccess("每天晚上提醒我写日记")
        XCTAssertEqual(parsed.title, "写日记")
        XCTAssertEqual(parsed.repeatRule?.type, .daily)
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T20:00:00+08:00"))
    }

    func testParsesDailyRepeatWithFuzzyNoon() throws {
        let parsed = try parseSuccess("每天中午提醒我吃药")
        XCTAssertEqual(parsed.title, "吃药")
        XCTAssertEqual(parsed.repeatRule?.type, .daily)
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T12:00:00+08:00"))
    }

    func testFullNLPCorpus() throws {
        let fixtures = try NLPFixtureLoader.loadFixtures()
        XCTAssertGreaterThanOrEqual(fixtures.count, 200)

        for fixture in fixtures {
            try assertFixture(fixture)
        }
    }

    private func parseSuccess(_ input: String, now: Date? = nil, settings: ParserSettings = .default) throws -> ParsedReminder {
        let result = parser.parse(input, now: now ?? self.now, calendar: calendar, settings: settings)
        guard case .success(let parsed) = result else {
            XCTFail("Expected success for \(input), got \(result)")
            throw TestError.unexpectedResult
        }
        return parsed
    }

    private func parseNeedsInput(_ input: String) throws -> ParsedReminder {
        let result = parser.parse(input, now: now, calendar: calendar, settings: .default)
        guard case .needsInput(let parsed) = result else {
            XCTFail("Expected needsInput for \(input), got \(result)")
            throw TestError.unexpectedResult
        }
        return parsed
    }

    private func assertFixture(_ fixture: NLPFixture) throws {
        let result = parser.parse(fixture.input, now: now, calendar: calendar, settings: .default)
        let parsed: ParsedReminder

        switch (fixture.expectedOutcome, result) {
        case ("success", .success(let value)),
             ("needs_input", .needsInput(let value)),
             ("unsupported", .needsInput(let value)),
             ("conflict", .needsInput(let value)):
            parsed = value
        default:
            XCTFail("\(fixture.id) expected \(fixture.expectedOutcome), got \(result)")
            throw TestError.unexpectedResult
        }

        XCTAssertEqual(parsed.title, fixture.expectedTitle, fixture.id)
        XCTAssertEqual(Set(parsed.missingFields.map(\.rawValue)), Set(fixture.expectedMissingFields), fixture.id)

        if let expectedDateTime = fixture.expectedDateTime {
            XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: expectedDateTime), fixture.id)
        } else if fixture.expectedOutcome != "needs_input" {
            XCTAssertNil(parsed.datetime, fixture.id)
        }

        if let expectedRepeat = fixture.expectedRepeat {
            XCTAssertEqual(parsed.repeatRule?.type.rawValue, expectedRepeat.type, fixture.id)
            if let interval = expectedRepeat.interval {
                XCTAssertEqual(parsed.repeatRule?.interval, interval, fixture.id)
            }
            if let weekday = expectedRepeat.weekday {
                XCTAssertEqual(parsed.repeatRule?.weekday, weekday, fixture.id)
            }
            if let dayOfMonth = expectedRepeat.dayOfMonth {
                XCTAssertEqual(parsed.repeatRule?.dayOfMonth, dayOfMonth, fixture.id)
            }
        } else {
            XCTAssertNil(parsed.repeatRule, fixture.id)
        }
    }
}

private enum TestError: Error {
    case unexpectedResult
}

private extension ISO8601DateFormatter {
    static let yijuhua: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
