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

    func testParsesTakeoutReminderTitleForNotificationDisplay() throws {
        let morning = ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T09:00:00+08:00")!

        let parsed = try parseSuccess("上午11点提醒我订外卖", now: morning)

        XCTAssertEqual(parsed.title, "订外卖")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T11:00:00+08:00"))
    }

    func testRemovesApproximateTimeSuffixFromTitle() throws {
        let cases: [(String, String)] = [
            ("下午5点左右去前台拿快递", "2026-05-24T17:00:00+08:00"),
            ("下午5点前后去前台拿快递", "2026-05-24T17:00:00+08:00"),
            ("下午5点上下去前台拿快递", "2026-05-24T17:00:00+08:00"),
            ("下午5点附近去前台拿快递", "2026-05-24T17:00:00+08:00"),
            ("17:00左右去前台拿快递", "2026-05-24T17:00:00+08:00"),
            ("下午5点半左右去前台拿快递", "2026-05-24T17:30:00+08:00")
        ]

        for (input, expectedDateTime) in cases {
            let parsed = try parseSuccess(input)
            XCTAssertEqual(parsed.title, "去前台拿快递", input)
            XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: expectedDateTime), input)
        }
    }

    func testPreciseTimeOverridesFuzzyPeriodAndCleansTitle() throws {
        let mondayEvening = ISO8601DateFormatter.yijuhua.date(from: "2026-06-08T18:34:00+08:00")!
        let cases: [(String, String)] = [
            ("周三下午3.30约了旺脉", "2026-06-10T15:30:00+08:00"),
            ("周三下午10.20约了旺脉", "2026-06-10T22:20:00+08:00"),
            ("周三下午5.40约了旺脉", "2026-06-10T17:40:00+08:00"),
            ("周三上午10.20约了旺脉", "2026-06-10T10:20:00+08:00"),
            ("周三下午8点45约了旺脉", "2026-06-10T20:45:00+08:00"),
            ("周三下午7点半约了旺脉", "2026-06-10T19:30:00+08:00")
        ]

        for (input, expectedDateTime) in cases {
            let parsed = try parseSuccess(input, now: mondayEvening)
            XCTAssertEqual(parsed.title, "约了旺脉", input)
            XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: expectedDateTime), input)
        }
    }

    func testKeepsThreeDigitNumberAfterHourAsTitleContent() throws {
        let threeDigit = try parseSuccess("明天下午3点360联盟过来拜访")
        XCTAssertEqual(threeDigit.title, "360联盟过来拜访")
        XCTAssertEqual(threeDigit.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T15:00:00+08:00"))

        let twoDigit = try parseSuccess("明天下午3点36联盟过来拜访")
        XCTAssertEqual(twoDigit.title, "联盟过来拜访")
        XCTAssertEqual(twoDigit.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T15:36:00+08:00"))
    }

    func testClassifiesReminderTags() throws {
        let friday = ISO8601DateFormatter.yijuhua.date(from: "2026-06-05T14:00:00+08:00")!
        let cases: [(String, ReminderTag, Date?)] = [
            ("明天上午拜访客户", .businessVisit, nil),
            ("明天上午10点提醒我开会", .meetingCommunication, nil),
            ("明天上午10点提醒我出差去深圳", .businessTrip, nil),
            ("下周一约下小米联盟时间", .waitingConfirmation, friday),
            ("明天上午11点提醒我订外卖", .dailyLife, nil),
            ("下周二下午4点打篮球", .leisure, friday),
            ("明天早上8点提醒我吃药", .health, nil),
            ("明天晚上8点提醒我学习", .learning, nil),
            ("明天上午10点提醒我看书", .learning, nil),
            ("明天上午10点提醒我研究 Kotlin", .learning, nil),
            ("明天上午10点提醒我玩游戏", .leisure, nil),
            ("明天上午10点提醒我打台球", .leisure, nil),
            ("明天上午10点提醒我看电影", .leisure, nil),
            ("明天上午10点提醒我旅游", .leisure, nil),
            ("明天上午10点提醒我瑜伽健身", .health, nil),
            ("明天上午10点提醒我跑步", .health, nil),
            ("明天上午10点提醒我锻炼", .health, nil),
            ("明天上午10点提醒我逛公园", .dailyLife, nil),
            ("明天上午10点提醒我买菜", .dailyLife, nil),
            ("明天上午10点提醒我做饭", .dailyLife, nil),
            ("明天上午10点提醒我洗衣服", .dailyLife, nil),
            ("明天上午10点提醒我打扫卫生", .dailyLife, nil),
            ("明天上午10点提醒我外出拜访", .businessVisit, nil),
            ("明天上午10点提醒我整理文件", .businessVisit, nil),
            ("明天上午10点提醒我打印合同", .businessVisit, nil),
            ("明天上午10点提醒我出差拜访客户", .businessTrip, nil),
            ("明天上午10点提醒我等客户确认报价", .waitingConfirmation, nil),
            ("明天上午10点提醒我开部门会议", .meetingCommunication, nil),
            ("明天上午10点提醒我订机票", .businessTrip, nil),
            ("明天上午10点提醒我收拾行李", .businessTrip, nil),
            ("明天上午10点提醒我展会布展", .businessTrip, nil),
            ("明天上午10点提醒我客户现场支持", .businessTrip, nil),
            ("明天上午10点提醒我问进度", .waitingConfirmation, nil),
            ("明天上午10点提醒我催客户确认", .waitingConfirmation, nil),
            ("明天上午10点提醒我等法务确认合同", .waitingConfirmation, nil),
            ("明天上午10点提醒我确认预算", .waitingConfirmation, nil),
            ("明天上午10点提醒我腾讯会议", .meetingCommunication, nil),
            ("明天上午10点提醒我需求评审", .meetingCommunication, nil),
            ("明天上午10点提醒我客户沟通", .meetingCommunication, nil),
            ("明天上午10点提醒我写周报", .businessVisit, nil),
            ("明天上午10点提醒我发邮件", .businessVisit, nil),
            ("明天上午10点提醒我做PPT", .businessVisit, nil),
            ("明天上午10点提醒我写PRD", .businessVisit, nil),
            ("明天上午10点提醒我发版上线", .businessVisit, nil),
            ("明天上午10点提醒我接口联调", .businessVisit, nil),
            ("明天上午10点提醒我整理客户名单", .businessVisit, nil),
            ("明天上午10点提醒我费用报销", .businessVisit, nil),
            ("明天上午10点提醒我催款回款", .businessVisit, nil),
            ("明天上午10点提醒我看数据报表", .businessVisit, nil),
            ("明天上午10点提醒我给妈妈打电话", .dailyLife, nil),
            ("明天上午10点提醒我取快递", .dailyLife, nil),
            ("明天上午10点提醒我遛狗", .dailyLife, nil),
            ("明天上午10点提醒我晒被子", .dailyLife, nil),
            ("明天上午10点提醒我换床单", .dailyLife, nil),
            ("明天上午10点提醒我关燃气", .dailyLife, nil),
            ("明天上午10点提醒我买鸡蛋", .dailyLife, nil),
            ("明天上午10点提醒我取外卖", .dailyLife, nil),
            ("明天上午10点提醒我去菜鸟驿站取件", .dailyLife, nil),
            ("明天上午10点提醒我交燃气费", .dailyLife, nil),
            ("明天上午10点提醒我还花呗", .dailyLife, nil),
            ("明天上午10点提醒我挪车", .dailyLife, nil),
            ("明天上午10点提醒我办身份证", .dailyLife, nil),
            ("明天上午10点提醒我给家里打电话", .dailyLife, nil),
            ("明天上午10点提醒我接孩子", .dailyLife, nil),
            ("明天上午10点提醒我家长会", .dailyLife, nil),
            ("明天上午10点提醒我敷面膜", .dailyLife, nil),
            ("明天上午10点提醒我配眼镜", .dailyLife, nil),
            ("明天上午10点提醒我跳绳", .health, nil),
            ("明天上午10点提醒我测血压", .health, nil),
            ("明天上午10点提醒我上网课", .learning, nil),
            ("明天上午10点提醒我考证", .learning, nil),
            ("明天上午10点提醒我约饭", .leisure, nil),
            ("明天上午10点提醒我爬山", .leisure, nil),
            ("明天上午10点提醒我追番", .leisure, nil),
            ("明天上午10点提醒我打王者荣耀", .leisure, nil),
            ("明天上午10点提醒我看音乐节", .leisure, nil),
            ("明天上午10点提醒我去 Livehouse", .leisure, nil),
            ("明天上午10点提醒我探店吃烤肉", .leisure, nil),
            ("明天上午10点提醒我朋友聚会", .leisure, nil),
            ("明天上午10点提醒我旅游订酒店", .leisure, nil),
            ("明天上午10点提醒我预约博物馆门票", .leisure, nil),
            ("明天上午10点提醒我逛夜市", .leisure, nil),
            ("明天上午10点提醒我打羽毛球", .leisure, nil),
            ("明天上午10点提醒我出差订酒店", .businessTrip, nil),
            ("明天上午10点提醒我整理桌面", .other, nil)
        ]

        for (input, expectedTag, now) in cases {
            let parsed = try parseSuccess(input, now: now)
            XCTAssertEqual(parsed.tag, expectedTag, input)
        }
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
        XCTAssertEqual(tonight.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T19:00:00+08:00"))

        let tomorrowMorning = try parseSuccess("明早提醒我带伞")
        XCTAssertEqual(tomorrowMorning.title, "带伞")
        XCTAssertEqual(tomorrowMorning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))

        let tomorrowNight = try parseSuccess("明晚八点半提醒我给家里打电话")
        XCTAssertEqual(tomorrowNight.title, "给家里打电话")
        XCTAssertEqual(tomorrowNight.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T20:30:00+08:00"))

        let dayAfterTomorrowAfternoon = try parseSuccess("后天下午提醒我寄合同")
        XCTAssertEqual(dayAfterTomorrowAfternoon.title, "寄合同")
        XCTAssertEqual(dayAfterTomorrowAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-26T14:00:00+08:00"))

        let fridayAfternoon = try parseSuccess("周五下午提醒我复盘")
        XCTAssertEqual(fridayAfternoon.title, "复盘")
        XCTAssertEqual(fridayAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-29T14:00:00+08:00"))
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

    func testRemovesCompleteWeekdayPrefixFromTitleWithoutReminderKeyword() throws {
        let friday = ISO8601DateFormatter.yijuhua.date(from: "2026-06-05T14:11:00+08:00")!

        let nextMonday = try parseSuccess("下周一约下倍业", now: friday)
        XCTAssertEqual(nextMonday.title, "约下倍业")
        XCTAssertEqual(nextMonday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-08T08:00:00+08:00"))

        let nextTuesday = try parseSuccess("下周二下午4点打篮球", now: friday)
        XCTAssertEqual(nextTuesday.title, "打篮球")
        XCTAssertEqual(nextTuesday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-09T16:00:00+08:00"))
    }

    func testKeepsPastWeekPhraseInTitleAfterNextWeekdayAnchor() throws {
        let thursday = ISO8601DateFormatter.yijuhua.date(from: "2026-06-11T15:05:00+08:00")!

        let parsed = try parseSuccess("下周一回去把上周各家媒体的情况都过一下", now: thursday)

        XCTAssertEqual(parsed.title, "回去把上周各家媒体的情况都过一下")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-15T08:00:00+08:00"))
    }

    func testParsesNextWeekdayAfterNamedDateAnchor() throws {
        let friday = ISO8601DateFormatter.yijuhua.date(from: "2026-06-12T09:00:00+08:00")!

        let parsed = try parseSuccess("618之后的下个周五请商务同学吃饭", now: friday)

        XCTAssertEqual(parsed.title, "请商务同学吃饭")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-26T08:00:00+08:00"))
    }

    func testRemovesLeadingPoliteParticleAfterReminderKeywordOnly() throws {
        let parsed = try parseSuccess("明天提醒我一下给客户发报价")

        XCTAssertEqual(parsed.title, "给客户发报价")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))
    }

    func testParsesPreciseCalendarDatePhrasesFromJuneThird() throws {
        let juneThirdMorning = ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T06:00:00+08:00")!

        let todayEarlyMorning = try parseSuccess("今天早上提醒我喝水", now: juneThirdMorning)
        XCTAssertEqual(todayEarlyMorning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T08:00:00+08:00"))

        let todayForenoon = try parseSuccess("今天上午提醒我打电话", now: juneThirdMorning)
        XCTAssertEqual(todayForenoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T10:00:00+08:00"))

        let todayNoon = try parseSuccess("今天中午提醒我吃饭", now: juneThirdMorning)
        XCTAssertEqual(todayNoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T12:00:00+08:00"))

        let todayAfternoon = try parseSuccess("今天下午提醒我开会", now: juneThirdMorning)
        XCTAssertEqual(todayAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T14:00:00+08:00"))

        let todayEvening = try parseSuccess("今天晚上提醒我复盘", now: juneThirdMorning)
        XCTAssertEqual(todayEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T19:00:00+08:00"))

        let preciseAfternoon = try parseSuccess("今天下午3点提醒我去汽水音乐", now: juneThirdMorning)
        XCTAssertEqual(preciseAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T15:00:00+08:00"))

        let preciseEvening = try parseSuccess("今天晚上10点提醒我关门", now: juneThirdMorning)
        XCTAssertEqual(preciseEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T22:00:00+08:00"))
    }

    func testParsesWeekMonthQuarterHalfYearAndFutureYearPhrases() throws {
        let juneThird = ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T06:00:00+08:00")!

        let thisThursday = try parseSuccess("本周4下午4点提醒我给客户打电话", now: juneThird)
        XCTAssertEqual(thisThursday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-04T16:00:00+08:00"))

        let nextMonth = try parseSuccess("下个月12号下午5点提醒我去上海", now: juneThird)
        XCTAssertEqual(nextMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-07-12T17:00:00+08:00"))

        let nextQuarter = try parseSuccess("下个季度8月份10号晚上11点提醒我去上海", now: juneThird)
        XCTAssertEqual(nextQuarter.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-08-10T23:00:00+08:00"))

        let secondHalf = try parseSuccess("下半年9月份11号晚上12点提醒我复盘", now: juneThird)
        XCTAssertEqual(secondHalf.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-09-12T00:00:00+08:00"))

        let nextYear = try parseSuccess("明年3月份8号中午12点提醒我做计划", now: juneThird)
        XCTAssertEqual(nextYear.datetime, ISO8601DateFormatter.yijuhua.date(from: "2027-03-08T12:00:00+08:00"))

        let yearAfterNext = try parseSuccess("后年3月份8号中午12点提醒我做计划", now: juneThird)
        XCTAssertEqual(yearAfterNext.datetime, ISO8601DateFormatter.yijuhua.date(from: "2028-03-08T12:00:00+08:00"))

        let explicitYear = try parseSuccess("2028年8月份8号凌晨2点提醒我看流星", now: juneThird)
        XCTAssertEqual(explicitYear.datetime, ISO8601DateFormatter.yijuhua.date(from: "2028-08-08T02:00:00+08:00"))
    }

    func testParsesNamedFestivalAndShoppingEventDates() throws {
        let cases: [(String, String, String)] = [
            ("618之后约下墨迹天气", "约下墨迹天气", "2026-06-19T08:00:00+08:00"),
            ("6.18之后约下墨迹天气", "约下墨迹天气", "2026-06-19T08:00:00+08:00"),
            ("618结束之后庆祝一下", "庆祝一下", "2026-06-19T10:00:00+08:00"),
            ("618活动结束后庆祝一下", "庆祝一下", "2026-06-19T10:00:00+08:00"),
            ("618那天上午8点约下墨迹天气", "约下墨迹天气", "2026-06-18T08:00:00+08:00"),
            ("618那天上午6.18约下墨迹天气", "约下墨迹天气", "2026-06-18T06:18:00+08:00"),
            ("6.18那天上午6.18约下墨迹天气", "约下墨迹天气", "2026-06-18T06:18:00+08:00"),
            ("6.18号下午6.18给墨迹的电话", "给墨迹的电话", "2026-06-18T18:18:00+08:00"),
            ("6.18号之后下午6.18给墨迹的电话", "给墨迹的电话", "2026-06-19T18:18:00+08:00"),
            ("6.18号以后下午6.18给墨迹的电话", "给墨迹的电话", "2026-06-19T18:18:00+08:00"),
            ("6.18号过后下午6.18给墨迹的电话", "给墨迹的电话", "2026-06-19T18:18:00+08:00"),
            ("6.18号后下午6.18给墨迹的电话", "给墨迹的电话", "2026-06-19T18:18:00+08:00"),
            ("6.18号给墨迹的电话", "给墨迹的电话", "2026-06-18T08:00:00+08:00"),
            ("双十一之后复盘活动", "复盘活动", "2026-11-12T08:00:00+08:00"),
            ("双11之后复盘活动", "复盘活动", "2026-11-12T08:00:00+08:00"),
            ("双十二之后整理账单", "整理账单", "2026-12-13T08:00:00+08:00"),
            ("元旦之后做年度计划", "做年度计划", "2027-01-04T08:00:00+08:00"),
            ("端午节之后回访客户", "回访客户", "2026-06-22T08:00:00+08:00"),
            ("端午节之后一起吃个饭", "一起吃个饭", "2026-06-22T08:00:00+08:00"),
            ("端午假期结束后回访客户", "回访客户", "2026-06-22T10:00:00+08:00"),
            ("过完端午回访客户", "回访客户", "2026-06-22T08:00:00+08:00"),
            ("中秋节之后寄礼盒", "寄礼盒", "2026-09-28T08:00:00+08:00"),
            ("国庆节之后约客户", "约客户", "2026-10-08T08:00:00+08:00"),
            ("七夕之后订餐厅", "订餐厅", "2026-08-20T08:00:00+08:00")
        ]

        for (input, expectedTitle, expectedDateTime) in cases {
            let parsed = try parseSuccess(input)
            XCTAssertEqual(parsed.title, expectedTitle, input)
            XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: expectedDateTime), input)
        }
    }

    func testParsesNamedFestivalDateWhenTitleIsMissing() throws {
        let parsed = try parseNeedsInput("双十一之后")

        XCTAssertEqual(parsed.title, "")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-11-12T08:00:00+08:00"))
        XCTAssertEqual(parsed.missingFields, [.title])
    }

    func testDotSeparatedNumberWithoutTimePeriodDoesNotBecomeTime() throws {
        let parsed = try parseNeedsInput("10.20约了旺脉")

        XCTAssertEqual(parsed.title, "10.20约了旺脉")
        XCTAssertNil(parsed.datetime)
        XCTAssertEqual(parsed.missingFields, [.time])
    }

    func testParsesDotSeparatedMonthDayWithSuffix() throws {
        let juneTwelfth = ISO8601DateFormatter.yijuhua.date(from: "2026-06-12T20:30:00+08:00")!

        let parsed = try parseSuccess("10.30号给中青打电话", now: juneTwelfth)

        XCTAssertEqual(parsed.title, "给中青打电话")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-10-30T08:00:00+08:00"))
    }

    func testParsesDotSeparatedTimeAfterDateAnchor() throws {
        let juneTwelfth = ISO8601DateFormatter.yijuhua.date(from: "2026-06-12T20:30:00+08:00")!

        let parsed = try parseSuccess("明天10.30给中青打电话", now: juneTwelfth)

        XCTAssertEqual(parsed.title, "给中青打电话")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-13T10:30:00+08:00"))
    }

    func testParsesRelativeYearMonthDayAndWeekWordsPrecisely() throws {
        let juneThird = ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T06:00:00+08:00")!

        let threeYearsAgo = try parseNeedsInput("大前年12月份1号提醒我复盘", now: juneThird)
        XCTAssertEqual(threeYearsAgo.title, "复盘")
        XCTAssertEqual(threeYearsAgo.datetime, ISO8601DateFormatter.yijuhua.date(from: "2023-12-01T08:00:00+08:00"))
        XCTAssertTrue(threeYearsAgo.missingFields.contains(.validFutureTime))

        let lastYearSameDay = try parseNeedsInput("去年提醒我复盘", now: juneThird)
        XCTAssertEqual(lastYearSameDay.title, "复盘")
        XCTAssertEqual(lastYearSameDay.datetime, ISO8601DateFormatter.yijuhua.date(from: "2025-06-03T08:00:00+08:00"))
        XCTAssertTrue(lastYearSameDay.missingFields.contains(.validFutureTime))

        let threeYearsLater = try parseSuccess("大后年提醒我复盘", now: juneThird)
        XCTAssertEqual(threeYearsLater.title, "复盘")
        XCTAssertEqual(threeYearsLater.datetime, ISO8601DateFormatter.yijuhua.date(from: "2029-06-03T08:00:00+08:00"))

        let twoMonthsAgo = try parseNeedsInput("上上个月提醒我复盘", now: juneThird)
        XCTAssertEqual(twoMonthsAgo.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-04-03T08:00:00+08:00"))
        XCTAssertTrue(twoMonthsAgo.missingFields.contains(.validFutureTime))

        let thisMonth = try parseSuccess("这个月12号提醒我交材料", now: juneThird)
        XCTAssertEqual(thisMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-12T08:00:00+08:00"))

        let twoMonthsLater = try parseSuccess("提醒我下下个月去上海", now: juneThird)
        XCTAssertEqual(twoMonthsLater.title, "去上海")
        XCTAssertEqual(twoMonthsLater.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-08-03T08:00:00+08:00"))

        let threeDaysAgo = try parseNeedsInput("大前天提醒我复盘", now: juneThird)
        XCTAssertEqual(threeDaysAgo.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-31T08:00:00+08:00"))
        XCTAssertTrue(threeDaysAgo.missingFields.contains(.validFutureTime))

        let yesterday = try parseNeedsInput("昨天提醒我复盘", now: juneThird)
        XCTAssertEqual(yesterday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-02T08:00:00+08:00"))
        XCTAssertTrue(yesterday.missingFields.contains(.validFutureTime))

        let threeDaysLater = try parseSuccess("大后天提醒我复盘", now: juneThird)
        XCTAssertEqual(threeDaysLater.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-06T08:00:00+08:00"))

        let twoWeeksAgoSameWeekday = try parseNeedsInput("提醒我上上周复盘", now: juneThird)
        XCTAssertEqual(twoWeeksAgoSameWeekday.title, "复盘")
        XCTAssertEqual(twoWeeksAgoSameWeekday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-20T08:00:00+08:00"))
        XCTAssertTrue(twoWeeksAgoSameWeekday.missingFields.contains(.validFutureTime))

        let lastWeekFriday = try parseNeedsInput("上周五下午3点提醒我复盘", now: juneThird)
        XCTAssertEqual(lastWeekFriday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-29T15:00:00+08:00"))
        XCTAssertTrue(lastWeekFriday.missingFields.contains(.validFutureTime))

        let twoWeeksLaterSameWeekday = try parseSuccess("下下周提醒我复盘", now: juneThird)
        XCTAssertEqual(twoWeeksLaterSameWeekday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-17T08:00:00+08:00"))

        let twoWeeksLaterFriday = try parseSuccess("下下周五下午3点提醒我复盘", now: juneThird)
        XCTAssertEqual(twoWeeksLaterFriday.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-19T15:00:00+08:00"))
    }

    func testRejectsInvalidCalendarDateWithoutRolling() throws {
        let juneThird = ISO8601DateFormatter.yijuhua.date(from: "2026-06-03T06:00:00+08:00")!

        let invalidDate = try parseNeedsInput("2028年2月份30号上午10点提醒我提交材料", now: juneThird)
        XCTAssertEqual(invalidDate.title, "提交材料")
        XCTAssertNil(invalidDate.datetime)
        XCTAssertTrue(invalidDate.missingFields.contains(.date))
    }

    func testParsesEndOfMonthAndWeekend() throws {
        let endOfMonth = try parseSuccess("月底提醒我交材料")
        XCTAssertEqual(endOfMonth.title, "交材料")
        XCTAssertEqual(endOfMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-31T08:00:00+08:00"))

        let endOfNextMonth = try parseSuccess("下个月底提醒我交房租")
        XCTAssertEqual(endOfNextMonth.title, "交房租")
        XCTAssertEqual(endOfNextMonth.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-30T08:00:00+08:00"))

        let tuesday = ISO8601DateFormatter.yijuhua.date(from: "2026-05-26T09:00:00+08:00")!
        let weekend = try parseSuccess("周末提醒我露营", now: tuesday)
        XCTAssertEqual(weekend.title, "露营")
        XCTAssertEqual(weekend.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-30T08:00:00+08:00"))

        let thisWeekend = try parseSuccess("本周末提醒我整理房间", now: tuesday)
        XCTAssertEqual(thisWeekend.title, "整理房间")
        XCTAssertEqual(thisWeekend.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-30T08:00:00+08:00"))

        let thisWeekendSundayAfternoon = try parseSuccess("本周末提醒我整理房间")
        XCTAssertEqual(thisWeekendSundayAfternoon.title, "整理房间")
        XCTAssertEqual(thisWeekendSundayAfternoon.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T19:00:00+08:00"))

        let sundayEvening = try parseSuccess("周日晚上提醒我给妈妈打电话")
        XCTAssertEqual(sundayEvening.title, "给妈妈打电话")
        XCTAssertEqual(sundayEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T19:00:00+08:00"))

        let weekendEvening = try parseSuccess("周末晚上提醒我看电影")
        XCTAssertEqual(weekendEvening.title, "看电影")
        XCTAssertEqual(weekendEvening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T19:00:00+08:00"))
    }

    func testUsesCustomDefaultTimeSettings() throws {
        var settings = ParserSettings.default
        settings.morningDefaultHour = 8
        settings.morningDefaultMinute = 30
        settings.eveningDefaultHour = 21
        settings.eveningDefaultMinute = 30

        let morning = try parseSuccess("明早提醒我带伞", settings: settings)
        XCTAssertEqual(morning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:30:00+08:00"))

        let evening = try parseSuccess("今晚提醒我整理账单", settings: settings)
        XCTAssertEqual(evening.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T21:30:00+08:00"))
    }

    func testLoadsHalfHourDefaultTimeSettingsFromUserDefaults() throws {
        let suiteName = "ReminderParserTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(8, forKey: "morningDefaultHour")
        defaults.set(30, forKey: "morningDefaultMinute")
        defaults.set(20, forKey: "eveningDefaultHour")
        defaults.set(30, forKey: "eveningDefaultMinute")

        let settings = ParserSettings.fromUserDefaults(defaults)
        XCTAssertEqual(settings.morningDefaultHour, 8)
        XCTAssertEqual(settings.morningDefaultMinute, 30)
        XCTAssertEqual(settings.eveningDefaultHour, 20)
        XCTAssertEqual(settings.eveningDefaultMinute, 30)

        let morning = try parseSuccess("明早提醒我带伞", settings: settings)
        XCTAssertEqual(morning.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:30:00+08:00"))
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

    func testParsesHourlyRepeatIntervals() throws {
        let cases: [(String, String, Int, String)] = [
            ("每小时提醒我喝水", "喝水", 1, "2026-05-24T17:00:00+08:00"),
            ("每两个小时提醒我喝水", "喝水", 2, "2026-05-24T18:00:00+08:00"),
            ("每三个小时提醒我检查一次", "检查一次", 3, "2026-05-24T19:00:00+08:00"),
            ("每8个小时提醒我吃药", "吃药", 8, "2026-05-25T00:00:00+08:00")
        ]

        for (input, expectedTitle, expectedInterval, expectedDateTime) in cases {
            let parsed = try parseSuccess(input)
            XCTAssertEqual(parsed.title, expectedTitle, input)
            XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: expectedDateTime), input)
            XCTAssertEqual(parsed.repeatRule?.type, .hourly, input)
            XCTAssertEqual(parsed.repeatRule?.interval, expectedInterval, input)
        }
    }

    func testParsesSupportedRepeatCategoriesFromNaturalLanguage() throws {
        let daily = try parseSuccess("每天上午10点提醒我吃药")
        XCTAssertEqual(daily.title, "吃药")
        XCTAssertEqual(daily.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T10:00:00+08:00"))
        XCTAssertEqual(daily.repeatRule?.type, .daily)

        let hourly = try parseSuccess("每小时提醒我喝水")
        XCTAssertEqual(hourly.title, "喝水")
        XCTAssertEqual(hourly.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T17:00:00+08:00"))
        XCTAssertEqual(hourly.repeatRule?.type, .hourly)
        XCTAssertEqual(hourly.repeatRule?.interval, 1)

        let weekly = try parseSuccess("每周三上午提醒我开部门会议")
        XCTAssertEqual(weekly.title, "开部门会议")
        XCTAssertEqual(weekly.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-27T10:00:00+08:00"))
        XCTAssertEqual(weekly.repeatRule?.type, .weekly)
        XCTAssertEqual(weekly.repeatRule?.interval, 1)
        XCTAssertEqual(weekly.repeatRule?.weekday, 3)

        let biweekly = try parseSuccess("每双周开会")
        XCTAssertEqual(biweekly.title, "开会")
        XCTAssertEqual(biweekly.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-07T08:00:00+08:00"))
        XCTAssertEqual(biweekly.repeatRule?.type, .weekly)
        XCTAssertEqual(biweekly.repeatRule?.interval, 2)

        let monthly = try parseSuccess("每月15号提醒我还款")
        XCTAssertEqual(monthly.title, "还款")
        XCTAssertEqual(monthly.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-15T08:00:00+08:00"))
        XCTAssertEqual(monthly.repeatRule?.type, .monthly)
        XCTAssertEqual(monthly.repeatRule?.dayOfMonth, 15)

        let weekdays = try parseSuccess("工作日上午9点提醒我打卡")
        XCTAssertEqual(weekdays.title, "打卡")
        XCTAssertEqual(weekdays.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T09:00:00+08:00"))
        XCTAssertEqual(weekdays.repeatRule?.type, .weekdays)
    }

    func testParsesBiweeklyRepeatPhrases() throws {
        let parsed = try parseSuccess("每双周开会")
        XCTAssertEqual(parsed.title, "开会")
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-07T08:00:00+08:00"))
        XCTAssertEqual(parsed.repeatRule?.type, .weekly)
        XCTAssertEqual(parsed.repeatRule?.interval, 2)
        XCTAssertNil(parsed.repeatRule?.weekday)

        let sundayEvening = ISO8601DateFormatter.yijuhua.date(from: "2026-06-14T20:00:00+08:00")!
        let mondayMeeting = try parseSuccess("每两周周一上午10点开例会", now: sundayEvening)
        XCTAssertEqual(mondayMeeting.title, "开例会")
        XCTAssertEqual(mondayMeeting.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-06-15T10:00:00+08:00"))
        XCTAssertEqual(mondayMeeting.repeatRule?.type, .weekly)
        XCTAssertEqual(mondayMeeting.repeatRule?.interval, 2)
        XCTAssertEqual(mondayMeeting.repeatRule?.weekday, 1)
    }

    func testNeedsInputForContextualTimePhrases() throws {
        let afterWork = try parseNeedsInput("明天下班前提醒我交材料")
        XCTAssertEqual(afterWork.title, "交材料")
        XCTAssertEqual(afterWork.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))
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
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))
        XCTAssertEqual(viewModel.timeSummary, "请选择时间")
        XCTAssertFalse(viewModel.canConfirm)

        XCTAssertFalse(viewModel.applySuggestion("自定义时间"))
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T08:00:00+08:00"))
        XCTAssertFalse(viewModel.didAdjustTime)

        XCTAssertTrue(viewModel.applySuggestion("当天晚上"))
        XCTAssertEqual(viewModel.remindAt, ISO8601DateFormatter.yijuhua.date(from: "2026-05-25T19:00:00+08:00"))
        XCTAssertTrue(viewModel.timeSummary.hasSuffix("19:00"))
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
        XCTAssertEqual(parsed.datetime, ISO8601DateFormatter.yijuhua.date(from: "2026-05-24T19:00:00+08:00"))
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

    private func parseNeedsInput(_ input: String, now: Date? = nil) throws -> ParsedReminder {
        let result = parser.parse(input, now: now ?? self.now, calendar: calendar, settings: .default)
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
