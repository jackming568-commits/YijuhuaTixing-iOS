import Foundation

protocol ReminderParsing {
    func parse(_ input: String, now: Date, calendar: Calendar, settings: ParserSettings) -> ParserResult
}

struct LocalReminderParser: ReminderParsing {
    private let durationNumberPattern = "(?:\\d+|[零一二两三四五六七八九十百]+)"
    private let clockMinutePattern = "(?:\\d{1,2}(?!\\d)|[零一二两三四五六七八九十]+(?![零一二两三四五六七八九十百千]))"
    private let approximateTimeSuffixPattern = "(?:左右|前后|上下|附近|多|来钟|出头)?"
    private let weekAnchorPattern = "(?:上上|上|下下|下一个|下个|下|本|这)?(?:周|星期|礼拜)[一二三四五六日天1-7]|(?:上上|上|下下|下一个|下个|下|本|这)(?:周|星期|礼拜)"
    private let biweeklyRepeatPattern = "每双周|每(?:隔)?(?:2|二|两)个?(?:周|星期|礼拜)|隔周"
    private let namedDateAfterMarkerPattern = "(?:(?:(?:活动|假期)\\s*)?结束\\s*)?(?:之后|以后|过后|后)"

    func parse(
        _ input: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        settings: ParserSettings = .default
    ) -> ParserResult {
        let normalized = normalize(input)
        guard !normalized.isEmpty else {
            return .failed(ParseFailure(rawInput: input, message: "输入为空", missingFields: [.title, .time], suggestions: defaultSuggestions()))
        }

        let rawRepeatRule = parseRepeatRule(from: normalized)
        let issueFields = parseIssueFields(from: normalized)
        let repeatRule = issueFields.contains(.repeatRule) ? nil : rawRepeatRule
        var dateResult = parseDate(from: normalized, now: now, calendar: calendar, settings: settings, repeatRule: repeatRule)
        if shouldInvalidateDate(for: issueFields, input: normalized) {
            dateResult = DateParseResult(date: nil, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }
        let title = extractTitle(from: normalized)
        let tag = ReminderTagClassifier.classify(title: title, rawInput: input)
        let missingFields = missingFields(
            title: title,
            date: dateResult.date,
            isPast: dateResult.isPast,
            issueFields: issueFields,
            hasTimeExpression: hasTimeExpression(in: normalized),
            hasDateExpression: hasCalendarDateExpression(in: normalized)
        )
        let confidence = score(title: title, dateResult: dateResult, repeatRule: repeatRule, missingFields: missingFields)

        let parsed = ParsedReminder(
            title: title,
            tag: tag,
            datetime: dateResult.date,
            repeatRule: repeatRule?.type == RepeatRuleType.none ? nil : repeatRule,
            confidence: confidence,
            needsUserConfirmation: true,
            missingFields: missingFields,
            rawInput: input,
            parseSource: .localRules,
            suggestions: suggestions(for: missingFields, date: dateResult.date)
        )

        if missingFields.isEmpty {
            return .success(parsed)
        }
        return .needsInput(parsed)
    }

    private func normalize(_ input: String) -> String {
        var output = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacements: [(String, String)] = [
            ("：", ":"),
            ("两", "2"),
            ("一个半小时", "1小时30分钟"),
            ("1个半小时", "1小时30分钟"),
            ("2个半小时", "2小时30分钟"),
            ("十点", "10点"),
            ("十一点", "11点"),
            ("十二点", "12点"),
            ("九点", "9点"),
            ("八点", "8点"),
            ("七点", "7点"),
            ("六点", "6点"),
            ("五点", "5点"),
            ("四点", "4点"),
            ("三点", "3点"),
            ("二点", "2点"),
            ("一点", "1点"),
            ("半个小时", "30分钟"),
            ("半小时", "30分钟"),
            ("一个小时", "1小时"),
            ("个小时", "小时")
        ]

        for (source, target) in replacements {
            output = output.replacingOccurrences(of: source, with: target)
        }

        return output.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private struct DateParseResult {
        var date: Date?
        var isPast: Bool
        var usedDefaultTime: Bool
        var hasAmbiguousTime: Bool
    }

    private struct NamedDateParseResult {
        var date: Date
        var rule: NamedDateRule
        var usesAfterDate: Bool
        var isYearPinned: Bool
    }

    private struct NamedDateRule {
        var aliasPattern: String
        var kind: NamedDateKind
        var afterOffsetDays: Int
        var afterKind: NamedDateAfterKind = .nextDay
    }

    private struct DotSeparatedMonthDay {
        var month: Int
        var day: Int
    }

    private enum NamedDateKind {
        case gregorian(month: Int, day: Int)
        case lunar(month: Int, day: Int)
        case lunarNewYearEve
        case qingming
        case weekdayInMonth(month: Int, weekday: Int, ordinal: Int)
    }

    private enum NamedDateAfterKind {
        case nextDay
        case shortPublicHoliday
        case springFestival
        case laborDay
        case nationalDay
        case midAutumn
    }

    private static let namedDateRules: [NamedDateRule] = [
        NamedDateRule(aliasPattern: "双十一|双11|11[\\.．]11", kind: .gregorian(month: 11, day: 11), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "双十二|双12|12[\\.．]12", kind: .gregorian(month: 12, day: 12), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "6[\\.．]18|618", kind: .gregorian(month: 6, day: 18), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "5[\\.．]20|520", kind: .gregorian(month: 5, day: 20), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "元旦节?|元旦", kind: .gregorian(month: 1, day: 1), afterOffsetDays: 1, afterKind: .shortPublicHoliday),
        NamedDateRule(aliasPattern: "春节|过年|大年初一", kind: .lunar(month: 1, day: 1), afterOffsetDays: 7, afterKind: .springFestival),
        NamedDateRule(aliasPattern: "除夕|大年三十", kind: .lunarNewYearEve, afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "元宵节?|元宵", kind: .lunar(month: 1, day: 15), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "龙抬头", kind: .lunar(month: 2, day: 2), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "清明节?|清明", kind: .qingming, afterOffsetDays: 1, afterKind: .shortPublicHoliday),
        NamedDateRule(aliasPattern: "劳动节|五一(?:劳动节)?", kind: .gregorian(month: 5, day: 1), afterOffsetDays: 5, afterKind: .laborDay),
        NamedDateRule(aliasPattern: "端午节?|端午", kind: .lunar(month: 5, day: 5), afterOffsetDays: 1, afterKind: .shortPublicHoliday),
        NamedDateRule(aliasPattern: "七夕节?|七夕", kind: .lunar(month: 7, day: 7), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "中秋节?|中秋", kind: .lunar(month: 8, day: 15), afterOffsetDays: 1, afterKind: .midAutumn),
        NamedDateRule(aliasPattern: "重阳节?|重阳", kind: .lunar(month: 9, day: 9), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "腊八节?|腊八", kind: .lunar(month: 12, day: 8), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "国庆节?|十一假期", kind: .gregorian(month: 10, day: 1), afterOffsetDays: 7, afterKind: .nationalDay),
        NamedDateRule(aliasPattern: "情人节", kind: .gregorian(month: 2, day: 14), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "妇女节|女神节", kind: .gregorian(month: 3, day: 8), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "植树节", kind: .gregorian(month: 3, day: 12), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "愚人节", kind: .gregorian(month: 4, day: 1), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "青年节", kind: .gregorian(month: 5, day: 4), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "儿童节|六一", kind: .gregorian(month: 6, day: 1), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "建党节", kind: .gregorian(month: 7, day: 1), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "建军节", kind: .gregorian(month: 8, day: 1), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "教师节", kind: .gregorian(month: 9, day: 10), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "万圣节", kind: .gregorian(month: 10, day: 31), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "平安夜", kind: .gregorian(month: 12, day: 24), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "圣诞节?|圣诞", kind: .gregorian(month: 12, day: 25), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "母亲节", kind: .weekdayInMonth(month: 5, weekday: 1, ordinal: 2), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "父亲节", kind: .weekdayInMonth(month: 6, weekday: 1, ordinal: 3), afterOffsetDays: 1),
        NamedDateRule(aliasPattern: "感恩节", kind: .weekdayInMonth(month: 11, weekday: 5, ordinal: 4), afterOffsetDays: 1)
    ]

    private func parseDate(
        from input: String,
        now: Date,
        calendar: Calendar,
        settings: ParserSettings,
        repeatRule: RepeatRule?
    ) -> DateParseResult {
        if let repeatRule, repeatRule.type == .hourly, !hasExplicitDateOrTimeExpression(in: input) {
            let interval = max(repeatRule.interval, 1)
            let date = calendar.date(byAdding: .hour, value: interval, to: now)
            return DateParseResult(date: date, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }

        if let relative = relativeDate(from: input, now: now, calendar: calendar) {
            return DateParseResult(date: relative, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }

        var baseDate: Date?
        var usedDefaultTime = false
        var ambiguous = false
        var namedDateResult: NamedDateParseResult?

        if input.contains("周末") {
            baseDate = weekendDate(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil {
            baseDate = namedDateNextWeekdayDate(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil {
            baseDate = weekDate(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil {
            baseDate = baseDay(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil {
            namedDateResult = namedDate(from: input, now: now, calendar: calendar)
            baseDate = namedDateResult?.date
        }

        if baseDate == nil, input.contains("月底") {
            baseDate = endOfMonthDate(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil {
            if let monthDate = monthDate(from: input, now: now, calendar: calendar) {
                baseDate = monthDate
            } else if hasCalendarDateExpression(in: input) {
                return DateParseResult(date: nil, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
            }
        }

        if baseDate == nil, input.contains("工作日") {
            baseDate = nextWeekdayBaseDate(from: now, calendar: calendar)
        }

        if baseDate == nil {
            baseDate = now
        }

        guard var date = baseDate else {
            return DateParseResult(date: nil, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }

        if let time = explicitTime(from: input, settings: settings) {
            if time.dayOffset > 0 {
                date = calendar.date(byAdding: .day, value: time.dayOffset, to: date) ?? date
            }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = time.hour
            components.minute = time.minute
            date = calendar.date(from: components) ?? date
            ambiguous = time.ambiguous
        } else if let fuzzy = fuzzyTime(from: input, settings: settings) {
            date = sameDayDate(as: date, hour: fuzzy.hour, minute: fuzzy.minute, calendar: calendar) ?? date
            usedDefaultTime = true
        } else if namedDateResult != nil, hasNamedDateEndMarker(in: input) {
            date = sameDayDate(as: date, hour: 10, minute: 0, calendar: calendar) ?? date
            usedDefaultTime = true
        } else if shouldUseDefaultMorning(for: input) {
            date = sameDayDate(
                as: date,
                hour: settings.morningDefaultHour,
                minute: settings.morningDefaultMinute,
                calendar: calendar
            ) ?? date
            usedDefaultTime = true
        } else if namedDateResult != nil {
            date = sameDayDate(
                as: date,
                hour: settings.morningDefaultHour,
                minute: settings.morningDefaultMinute,
                calendar: calendar
            ) ?? date
            usedDefaultTime = true
        } else if hasContextualTimeExpression(in: input), hasAbsoluteDayExpression(in: input) {
            date = sameDayDate(
                as: date,
                hour: settings.morningDefaultHour,
                minute: settings.morningDefaultMinute,
                calendar: calendar
            ) ?? date
            usedDefaultTime = true
        } else {
            return DateParseResult(date: nil, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }

        if date <= now, repeatRule == nil, hasWeekdayExpression(in: input), weekOffset(in: input) == nil {
            date = calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }

        if date <= now,
           repeatRule == nil,
           usedDefaultTime,
           hasWeekendExpression(in: input),
           containsThisWeekExpression(in: input),
           let eveningDate = sameDayDate(
                as: date,
                hour: settings.eveningDefaultHour,
                minute: settings.eveningDefaultMinute,
                calendar: calendar
           ),
           eveningDate > now {
            date = eveningDate
        }

        if date <= now, repeatRule == nil, hasWeekendExpression(in: input), weekOffset(in: input) == nil {
            date = nextWeekendDate(keepingTimeFrom: date, after: now, calendar: calendar) ?? date
        }

        if date <= now,
           repeatRule == nil,
           let namedDateResult,
           !namedDateResult.isYearPinned {
            date = nextNamedDate(
                matching: namedDateResult,
                keepingTimeFrom: date,
                now: now,
                calendar: calendar
            ) ?? date
        }

        if date <= now, let repeatRule, repeatRule.isRepeating, let next = repeatRule.nextDate(after: date, calendar: calendar) {
            date = next
        }

        return DateParseResult(date: date, isPast: date <= now, usedDefaultTime: usedDefaultTime, hasAmbiguousTime: ambiguous)
    }

    private func relativeDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        if let values = firstMatch(pattern: "(\(durationNumberPattern))小时(\(durationNumberPattern))分钟(?:后|以后)", in: input), values.count == 2 {
            let hours = durationInteger(from: values[0]) ?? 0
            let minutes = durationInteger(from: values[1]) ?? 0
            return calendar.date(byAdding: .minute, value: hours * 60 + minutes, to: now)
        }
        if let minutes = firstDurationInteger(before: "分钟(?:后|以后)", in: input) {
            return calendar.date(byAdding: .minute, value: minutes, to: now)
        }
        if let hours = firstDurationInteger(before: "小时(?:后|以后)", in: input) {
            return calendar.date(byAdding: .hour, value: hours, to: now)
        }
        if let minutes = firstDurationInteger(after: "过", before: "分钟", in: input) {
            return calendar.date(byAdding: .minute, value: minutes, to: now)
        }
        if let hours = firstDurationInteger(after: "过", before: "小时", in: input) {
            return calendar.date(byAdding: .hour, value: hours, to: now)
        }
        if input.contains("过30分钟") {
            return calendar.date(byAdding: .minute, value: 30, to: now)
        }
        if input.contains("待会") || input.contains("一会儿") || input.contains("过一会儿") {
            return calendar.date(byAdding: .minute, value: 10, to: now)
        }
        return nil
    }

    private func endOfMonthDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        let referenceDate = calendar.date(byAdding: .month, value: relativeMonthOffset(in: input) ?? 0, to: now) ?? now

        guard
            let range = calendar.range(of: .day, in: .month, for: referenceDate),
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))
        else {
            return nil
        }

        return calendar.date(byAdding: .day, value: range.count - 1, to: monthStart)
    }

    private func weekendDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: now)
        let todayMondayBased = mondayBasedWeekday(from: calendar.component(.weekday, from: now))

        if let weekOffset = weekOffset(in: input) {
            if weekOffset == 0, todayMondayBased == 7 {
                return start
            }
            guard let currentWeekMonday = calendar.date(byAdding: .day, value: 1 - todayMondayBased, to: start) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: weekOffset * 7 + 5, to: currentWeekMonday)
        }

        if containsNextWeekExpression(in: input) {
            let daysUntilNextMonday = 8 - todayMondayBased
            return calendar.date(byAdding: .day, value: daysUntilNextMonday + 5, to: start)
        }

        if containsThisWeekExpression(in: input) {
            if todayMondayBased <= 6 {
                return calendar.date(byAdding: .day, value: 6 - todayMondayBased, to: start)
            }
            return start
        }

        if todayMondayBased == 7 {
            return start
        }

        return calendar.date(byAdding: .day, value: 6 - todayMondayBased, to: start)
    }

    private func nextWeekendDate(keepingTimeFrom date: Date, after now: Date, calendar: Calendar) -> Date? {
        var cursor = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? calendar.startOfDay(for: now)
        for _ in 0..<8 {
            if calendar.component(.weekday, from: cursor) == 7 {
                var components = calendar.dateComponents([.year, .month, .day], from: cursor)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                return calendar.date(from: components)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return nil
    }

    private func sameDayDate(as date: Date, hour: Int, minute: Int = 0, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private func baseDay(from input: String, now: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: now)
        if input.contains("大前天") {
            return calendar.date(byAdding: .day, value: -3, to: start)
        }
        if input.contains("前天") {
            return calendar.date(byAdding: .day, value: -2, to: start)
        }
        if input.contains("昨天") {
            return calendar.date(byAdding: .day, value: -1, to: start)
        }
        if input.contains("大后天") {
            return calendar.date(byAdding: .day, value: 3, to: start)
        }
        if input.contains("后天") {
            return calendar.date(byAdding: .day, value: 2, to: start)
        }
        if input.contains("明天") || input.contains("明早") || input.contains("明晚") {
            return calendar.date(byAdding: .day, value: 1, to: start)
        }
        if input.contains("今天") || input.contains("今晚") {
            return start
        }
        return nil
    }

    private func nextWeekdayBaseDate(from now: Date, calendar: Calendar) -> Date {
        var cursor = calendar.startOfDay(for: now)
        for _ in 0..<8 {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 {
                return cursor
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return calendar.startOfDay(for: now)
    }

    private func weekDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        let weekOffset = weekOffset(in: input)
        guard let target = weekdayValue(in: input) ?? (weekOffset == nil ? nil : mondayBasedWeekday(from: calendar.component(.weekday, from: now))) else {
            return nil
        }

        let todayMondayBased = mondayBasedWeekday(from: calendar.component(.weekday, from: now))
        let start = calendar.startOfDay(for: now)

        if let weekOffset {
            guard let currentWeekMonday = calendar.date(byAdding: .day, value: 1 - todayMondayBased, to: start) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: weekOffset * 7 + target - 1, to: currentWeekMonday)
        }

        var delta = target - todayMondayBased
        if delta < 0 {
            delta += 7
        }
        return calendar.date(byAdding: .day, value: delta, to: start)
    }

    private func monthDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        let dotSeparatedMonthDay = dotSeparatedMonthDay(in: input)
        let explicitDay = dotSeparatedMonthDay?.day ?? explicitDay(in: input)
        let explicitMonth = dotSeparatedMonthDay?.month ?? explicitMonth(in: input)
        let monthOffset = relativeMonthOffset(in: input)
        let yearOffset = relativeYearOffset(in: input)

        guard explicitDay != nil || explicitMonth != nil || monthOffset != nil || yearOffset != nil else {
            return nil
        }

        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        guard let currentYear = nowComponents.year,
              let currentMonth = nowComponents.month,
              let currentDay = nowComponents.day else {
            return nil
        }
        var year = currentYear
        var month = currentMonth

        if let explicitYear = explicitYear(in: input) {
            year = explicitYear
            if let explicitMonth {
                month = explicitMonth
            }
        } else if let yearOffset {
            year += yearOffset
            if let explicitMonth {
                month = explicitMonth
            }
        } else if let monthOffset {
            let shiftedMonth = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
            let shiftedMonthComponents = calendar.dateComponents([.year, .month], from: shiftedMonth)
            year = shiftedMonthComponents.year ?? year
            month = shiftedMonthComponents.month ?? month
        } else if containsNextQuarterExpression(in: input) {
            let nextQuarter = nextQuarterStart(fromYear: currentYear, month: currentMonth)
            year = nextQuarter.year
            month = explicitMonth ?? nextQuarter.month
            guard month >= nextQuarter.month && month < nextQuarter.month + 3 else {
                return nil
            }
        } else if input.contains("下半年") {
            year = currentMonth <= 6 ? currentYear : currentYear + 1
            month = explicitMonth ?? 7
            guard (7...12).contains(month) else {
                return nil
            }
        } else if let explicitMonth {
            month = explicitMonth
        }

        if let explicitDay {
            return strictDate(year: year, month: month, day: explicitDay, calendar: calendar)
        }
        return clampedDate(year: year, month: month, preferredDay: currentDay, calendar: calendar)
    }

    private func explicitYear(in input: String) -> Int? {
        firstMatch(pattern: "(\\d{4})年", in: input)?.first.flatMap(Int.init)
    }

    private func explicitMonth(in input: String) -> Int? {
        guard let rawValue = firstMatch(pattern: "(?:\\d{4}年)?(\(durationNumberPattern))月份?", in: input)?.first,
              let month = durationInteger(from: rawValue),
              (1...12).contains(month) else {
            return nil
        }
        return month
    }

    private func explicitDay(in input: String) -> Int? {
        firstInteger(before: "号", in: input) ??
        firstInteger(before: "日", in: input) ??
        dayAfterMonth(in: input)
    }

    private func strictDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            return nil
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }

        return date
    }

    private func clampedDate(year: Int, month: Int, preferredDay: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month),
              let monthStart = strictDate(year: year, month: month, day: 1, calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        return strictDate(year: year, month: month, day: min(preferredDay, range.count), calendar: calendar)
    }

    private func nextQuarterStart(fromYear year: Int, month: Int) -> (year: Int, month: Int) {
        let currentQuarterStartMonth = ((month - 1) / 3) * 3 + 1
        let nextQuarterStartMonth = currentQuarterStartMonth + 3
        if nextQuarterStartMonth > 12 {
            return (year + 1, 1)
        }
        return (year, nextQuarterStartMonth)
    }

    private var namedDateExpressionPattern: String {
        Self.namedDateRules.map(\.aliasPattern).joined(separator: "|")
    }

    private var namedDateTitlePattern: String {
        "(?:(?:过完|过了)\\s*)?(?:\(namedDateExpressionPattern))\\s*(?:号|日|那天|当天|这天)?\\s*(?:\(namedDateAfterMarkerPattern))?"
    }

    private var dotSeparatedMonthDayTitlePattern: String {
        "\\d{1,2}[\\.．]\\d{1,2}\\s*(?:号|日|那天|当天|这天)"
    }

    private var namedDateNextWeekdayTitlePattern: String {
        "(?:\(namedDateExpressionPattern))\\s*(?:号|日|那天|当天|这天)?\\s*\(namedDateAfterMarkerPattern)\\s*的?\\s*(?:(?:下一个|下个)(?:周|星期|礼拜)|下(?:周|星期|礼拜))[一二三四五六日天1-7]"
    }

    private func namedDate(from input: String, now: Date, calendar: Calendar) -> NamedDateParseResult? {
        for rule in Self.namedDateRules {
            guard let usesAfterDate = namedDateMatch(for: rule, in: input) else {
                continue
            }

            let currentYear = calendar.component(.year, from: now)
            let pinnedYear = explicitYear(in: input) != nil || relativeYearOffset(in: input) != nil
            var targetYear = explicitYear(in: input) ?? currentYear
            if let yearOffset = relativeYearOffset(in: input), explicitYear(in: input) == nil {
                targetYear = currentYear + yearOffset
            }

            guard var date = resolvedNamedDate(rule, year: targetYear, usesAfterDate: usesAfterDate, calendar: calendar) else {
                return nil
            }

            if !pinnedYear,
               let dayAfterDate = calendar.date(byAdding: .day, value: 1, to: date),
               dayAfterDate <= now,
               let nextDate = resolvedNamedDate(rule, year: targetYear + 1, usesAfterDate: usesAfterDate, calendar: calendar) {
                date = nextDate
            }

            return NamedDateParseResult(date: date, rule: rule, usesAfterDate: usesAfterDate, isYearPinned: pinnedYear)
        }

        return nil
    }

    private func namedDateNextWeekdayDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        for rule in Self.namedDateRules {
            let pattern = "(\(rule.aliasPattern))\\s*(?:号|日|那天|当天|这天)?\\s*\(namedDateAfterMarkerPattern)\\s*的?\\s*(?:(?:下一个|下个)(?:周|星期|礼拜)|下(?:周|星期|礼拜))([一二三四五六日天1-7])"
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
            guard let match = regex.firstMatch(in: input, range: nsRange),
                  let weekdayText = matchedString(at: 2, in: input, match: match),
                  let targetWeekday = weekdayNumber(from: weekdayText) else {
                continue
            }

            let currentYear = calendar.component(.year, from: now)
            let pinnedYear = explicitYear(in: input) != nil || relativeYearOffset(in: input) != nil
            var targetYear = explicitYear(in: input) ?? currentYear
            if let yearOffset = relativeYearOffset(in: input), explicitYear(in: input) == nil {
                targetYear = currentYear + yearOffset
            }

            guard var date = namedDateNextWeekdayDate(
                rule: rule,
                year: targetYear,
                targetWeekday: targetWeekday,
                calendar: calendar
            ) else {
                return nil
            }

            if !pinnedYear,
               date <= now,
               let nextDate = namedDateNextWeekdayDate(
                   rule: rule,
                   year: targetYear + 1,
                   targetWeekday: targetWeekday,
                   calendar: calendar
               ) {
                date = nextDate
            }

            return date
        }

        return nil
    }

    private func namedDateNextWeekdayDate(
        rule: NamedDateRule,
        year: Int,
        targetWeekday: Int,
        calendar: Calendar
    ) -> Date? {
        guard let anchor = namedDateBaseDate(for: rule.kind, year: year, calendar: calendar) else {
            return nil
        }

        let start = calendar.startOfDay(for: anchor)
        let anchorWeekday = mondayBasedWeekday(from: calendar.component(.weekday, from: start))
        guard let anchorWeekMonday = calendar.date(byAdding: .day, value: 1 - anchorWeekday, to: start) else {
            return nil
        }

        return calendar.date(byAdding: .day, value: 7 + targetWeekday - 1, to: anchorWeekMonday)
    }

    private func namedDateMatch(for rule: NamedDateRule, in input: String) -> Bool? {
        let pattern = "((?:过完|过了)\\s*)?(\(rule.aliasPattern))\\s*(?:号|日|那天|当天|这天)?\\s*(\(namedDateAfterMarkerPattern))?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: nsRange) else {
            return nil
        }

        return match.range(at: 1).location != NSNotFound || match.range(at: 3).location != NSNotFound
    }

    private func hasNamedDateEndMarker(in input: String) -> Bool {
        let pattern = "(?:\(namedDateExpressionPattern))\\s*(?:号|日|那天|当天|这天)?\\s*(?:(?:活动|假期)\\s*)?结束\\s*(?:之后|以后|过后|后)"
        return input.range(of: pattern, options: .regularExpression) != nil
    }

    private func nextNamedDate(
        matching namedDateResult: NamedDateParseResult,
        keepingTimeFrom date: Date,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let nextYear = calendar.component(.year, from: now) + 1
        guard let nextBase = resolvedNamedDate(
            namedDateResult.rule,
            year: nextYear,
            usesAfterDate: namedDateResult.usesAfterDate,
            calendar: calendar
        ) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: nextBase)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }

    private func resolvedNamedDate(
        _ rule: NamedDateRule,
        year: Int,
        usesAfterDate: Bool,
        calendar: Calendar
    ) -> Date? {
        guard var date = namedDateBaseDate(for: rule.kind, year: year, calendar: calendar) else {
            return nil
        }

        if usesAfterDate {
            date = dateAfterNamedDate(rule, base: date, year: year, calendar: calendar)
        }
        return calendar.startOfDay(for: date)
    }

    private func dateAfterNamedDate(
        _ rule: NamedDateRule,
        base: Date,
        year: Int,
        calendar: Calendar
    ) -> Date {
        switch rule.afterKind {
        case .nextDay:
            return calendar.date(byAdding: .day, value: rule.afterOffsetDays, to: base) ?? base
        case .shortPublicHoliday:
            return dateAfterShortPublicHoliday(anchor: base, calendar: calendar)
        case .springFestival:
            return dateAfterSpringFestival(lunarNewYear: base, calendar: calendar)
        case .laborDay:
            return calendar.date(byAdding: .day, value: 5, to: base) ?? base
        case .nationalDay:
            return dateAfterNationalHoliday(year: year, calendar: calendar) ?? base
        case .midAutumn:
            return dateAfterMidAutumnHoliday(anchor: base, calendar: calendar)
        }
    }

    private func dateAfterShortPublicHoliday(anchor: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: anchor)
        let offset: Int
        switch weekday {
        case 5, 6, 7:
            offset = 3
        case 1:
            offset = 2
        default:
            offset = 1
        }
        return calendar.date(byAdding: .day, value: offset, to: anchor) ?? anchor
    }

    private func dateAfterSpringFestival(lunarNewYear: Date, calendar: Calendar) -> Date {
        let regularAfterHoliday = calendar.date(byAdding: .day, value: 7, to: lunarNewYear) ?? lunarNewYear
        guard let lunarNewYearEve = calendar.date(byAdding: .day, value: -1, to: lunarNewYear),
              calendar.component(.weekday, from: lunarNewYearEve) == 6 else {
            return regularAfterHoliday
        }
        return calendar.date(byAdding: .day, value: 8, to: lunarNewYear) ?? regularAfterHoliday
    }

    private func dateAfterNationalHoliday(year: Int, calendar: Calendar) -> Date? {
        guard let octoberFirst = strictDate(year: year, month: 10, day: 1, calendar: calendar),
              let regularAfterHoliday = strictDate(year: year, month: 10, day: 8, calendar: calendar) else {
            return nil
        }

        if let midAutumn = lunarDate(gregorianYear: year, month: 8, day: 15, calendar: calendar),
           midAutumn >= octoberFirst,
           midAutumn <= regularAfterHoliday {
            return strictDate(year: year, month: 10, day: 9, calendar: calendar) ?? regularAfterHoliday
        }
        return regularAfterHoliday
    }

    private func dateAfterMidAutumnHoliday(anchor: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: anchor)
        if components.month == 10,
           let day = components.day,
           (1...8).contains(day),
           let year = components.year {
            return strictDate(year: year, month: 10, day: 9, calendar: calendar) ?? anchor
        }
        return dateAfterShortPublicHoliday(anchor: anchor, calendar: calendar)
    }

    private func namedDateBaseDate(for kind: NamedDateKind, year: Int, calendar: Calendar) -> Date? {
        switch kind {
        case let .gregorian(month, day):
            return strictDate(year: year, month: month, day: day, calendar: calendar)
        case let .lunar(month, day):
            return lunarDate(gregorianYear: year, month: month, day: day, calendar: calendar)
        case .lunarNewYearEve:
            guard let nextSpringFestival = lunarDate(gregorianYear: year + 1, month: 1, day: 1, calendar: calendar) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: -1, to: nextSpringFestival)
        case .qingming:
            return qingmingDate(year: year, calendar: calendar)
        case let .weekdayInMonth(month, weekday, ordinal):
            return weekdayInMonthDate(year: year, month: month, weekday: weekday, ordinal: ordinal, calendar: calendar)
        }
    }

    private func lunarDate(gregorianYear: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = calendar.timeZone

        var chineseCalendar = Calendar(identifier: .chinese)
        chineseCalendar.timeZone = calendar.timeZone

        guard let start = strictDate(year: gregorianYear, month: 1, day: 1, calendar: gregorianCalendar),
              let end = strictDate(year: gregorianYear + 1, month: 1, day: 1, calendar: gregorianCalendar) else {
            return nil
        }

        var cursor = start
        while cursor < end {
            let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: cursor)
            if components.month == month,
               components.day == day,
               components.isLeapMonth != true {
                return calendar.startOfDay(for: cursor)
            }
            cursor = gregorianCalendar.date(byAdding: .day, value: 1, to: cursor) ?? end
        }

        return nil
    }

    private func qingmingDate(year: Int, calendar: Calendar) -> Date? {
        let shortYear = year % 100
        let day = Int(floor(Double(shortYear) * 0.2422 + 4.81)) - Int(floor(Double(shortYear - 1) / 4.0))
        return strictDate(year: year, month: 4, day: day, calendar: calendar)
    }

    private func weekdayInMonthDate(
        year: Int,
        month: Int,
        weekday: Int,
        ordinal: Int,
        calendar: Calendar
    ) -> Date? {
        guard let monthStart = strictDate(year: year, month: month, day: 1, calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }

        var matchedCount = 0
        for day in range {
            guard let date = strictDate(year: year, month: month, day: day, calendar: calendar) else {
                continue
            }
            if calendar.component(.weekday, from: date) == weekday {
                matchedCount += 1
                if matchedCount == ordinal {
                    return date
                }
            }
        }

        return nil
    }

    private func explicitTime(from input: String, settings: ParserSettings) -> (hour: Int, minute: Int, ambiguous: Bool, dayOffset: Int)? {
        if let match = firstMatch(pattern: "(\\d{1,2})[:：](\\d{1,2})", in: input), match.count == 2 {
            let hour = Int(match[0]) ?? -1
            let minute = Int(match[1]) ?? -1
            return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: true)
        }

        if let time = decimalClockTime(from: input, settings: settings) {
            return time
        }

        guard let hour = firstInteger(before: "点", in: input) else {
            return nil
        }

        var minute = 0
        if input.contains("点半") {
            minute = 30
        } else if let value = minuteAfterHourMarker(in: input) {
            minute = value
        }

        if input.contains("下午") || input.contains("晚上") || input.contains("今晚") || input.contains("明晚") {
            return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: false)
        }

        if input.contains("中午") {
            return adjustedTime(hour: hour == 0 || hour > 12 ? settings.noonDefaultHour : hour, minute: minute, input: input, settings: settings, colonStyle: false)
        }

        if input.contains("凌晨") || input.contains("早上") || input.contains("上午") || input.contains("明早") {
            return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: false)
        }

        if hour >= 13 {
            return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: false)
        }

        if hour >= 1 && hour <= 6 {
            return adjustedTime(hour: hour + 12, minute: minute, input: input, settings: settings, colonStyle: false, ambiguous: true)
        }

        return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: false, ambiguous: true)
    }

    private func decimalClockTime(
        from input: String,
        settings: ParserSettings
    ) -> (hour: Int, minute: Int, ambiguous: Bool, dayOffset: Int)? {
        for match in decimalClockTimeMatches(in: input) {
            guard shouldTreatAsDecimalClockTime(before: match.before) else {
                continue
            }

            return adjustedTime(
                hour: match.hour,
                minute: match.minute,
                input: input,
                settings: settings,
                colonStyle: false,
                ambiguous: false
            )
        }

        return nil
    }

    private func decimalClockTimeMatches(
        in input: String
    ) -> [(hour: Int, minute: Int, before: String)] {
        let pattern = "(\\d{1,2})[\\.．](\\d{1,2})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, range: nsRange)
        var result: [(hour: Int, minute: Int, before: String)] = []

        for match in matches where match.numberOfRanges == 3 {
            guard
                let fullRange = Range(match.range(at: 0), in: input),
                let hourRange = Range(match.range(at: 1), in: input),
                let minuteRange = Range(match.range(at: 2), in: input),
                let hour = Int(input[hourRange]),
                let minute = Int(input[minuteRange])
            else {
                continue
            }

            let before = String(input[..<fullRange.lowerBound])
            result.append((hour: hour, minute: minute, before: before))
        }

        return result
    }

    private func shouldTreatAsDecimalClockTime(before: String) -> Bool {
        hasNearbyTimePeriod(before: before) || hasNearbyDateAnchor(before: before)
    }

    private func hasDecimalClockTimeExpression(in input: String) -> Bool {
        decimalClockTimeMatches(in: input).contains { match in
            shouldTreatAsDecimalClockTime(before: match.before)
        }
    }

    private func hasNearbyTimePeriod(before: String) -> Bool {
        let nearbyPrefix = String(before.suffix(8))
        return nearbyPrefix.range(of: "凌晨|早上|上午|中午|下午|晚上|今晚|明晚|明早", options: .regularExpression) != nil
    }

    private func hasNearbyDateAnchor(before: String) -> Bool {
        let nearbyPrefix = String(before.suffix(16))
        return hasAbsoluteDayExpression(in: nearbyPrefix)
    }

    private func fuzzyTime(from input: String, settings: ParserSettings) -> (hour: Int, minute: Int)? {
        if input.contains("凌晨") {
            return (settings.earlyMorningDefaultHour, 0)
        }
        if input.contains("明早") || input.contains("早上") {
            return (settings.morningDefaultHour, settings.morningDefaultMinute)
        }
        if input.contains("上午") {
            return (settings.forenoonDefaultHour, 0)
        }
        if input.contains("中午") {
            return (settings.noonDefaultHour, 0)
        }
        if input.contains("下午") {
            return (settings.afternoonDefaultHour, 0)
        }
        if input.contains("今晚") || input.contains("明晚") || input.contains("晚上") {
            return (settings.eveningDefaultHour, settings.eveningDefaultMinute)
        }
        return nil
    }

    private func shouldUseDefaultMorning(for input: String) -> Bool {
        hasAbsoluteDayExpression(in: input) ||
        input.contains("号") ||
        input.contains("每周") ||
        input.contains("每个周") ||
        input.contains("每个星期") ||
        input.contains("每个礼拜") ||
        hasBiweeklyRepeatExpression(in: input) ||
        input.contains("每月") ||
        input.contains("每个月") ||
        input.contains("月底") ||
        input.contains("周末")
    }

    private func parseRepeatRule(from input: String) -> RepeatRule? {
        if let interval = hourlyInterval(in: input) {
            return RepeatRule(type: .hourly, interval: interval, weekday: nil, dayOfMonth: nil)
        }
        if input.contains("工作日") {
            return RepeatRule(type: .weekdays, interval: 1, weekday: nil, dayOfMonth: nil)
        }
        if input.contains("每天") {
            return RepeatRule(type: .daily, interval: 1, weekday: nil, dayOfMonth: nil)
        }
        if hasBiweeklyRepeatExpression(in: input) {
            let weekday = weekdayValue(in: input)
            return RepeatRule(type: .weekly, interval: 2, weekday: weekday, dayOfMonth: nil)
        }
        if input.contains("每周") || input.contains("每个周") || input.contains("每个星期") || input.contains("每个礼拜") {
            let weekday = weekdayValue(in: input)
            return RepeatRule(type: .weekly, interval: 1, weekday: weekday, dayOfMonth: nil)
        }
        if input.contains("每月") || input.contains("每个月") {
            let day = firstInteger(before: "号", in: input)
            return RepeatRule(type: .monthly, interval: 1, weekday: nil, dayOfMonth: day)
        }
        return nil
    }

    private func hasBiweeklyRepeatExpression(in input: String) -> Bool {
        input.range(of: biweeklyRepeatPattern, options: .regularExpression) != nil
    }

    private func hourlyInterval(in input: String) -> Int? {
        if input.contains("每小时") {
            return 1
        }

        guard let values = firstMatch(pattern: "每(?:隔)?(\(durationNumberPattern))小时", in: input),
              let rawValue = values.first,
              let interval = durationInteger(from: rawValue),
              interval > 0 else {
            return nil
        }
        return interval
    }

    private func extractTitle(from input: String) -> String {
        if occurrenceCount(of: "提醒我", in: input) > 1 {
            return ""
        }

        var title = input
        if let range = input.range(of: "提醒我") {
            title = String(input[range.upperBound...])
            if title.hasPrefix("一下") {
                title.removeFirst("一下".count)
            }
        }

        title = removingFirstOccurrence(of: namedDateNextWeekdayTitlePattern, from: title)
        title = removingFirstOccurrence(of: weekAnchorPattern, from: title)

        let patterns = [
            namedDateTitlePattern,
            dotSeparatedMonthDayTitlePattern,
            "大前年|前年|去年|大后年|后年|明年|今年|下个季度|下季度|下半年",
            "\\d{4}年",
            "(?:凌晨|早上|上午|中午|下午|晚上|今晚|明晚|明早)\\s*\\d{1,2}[\\.．]\\d{1,2}\(approximateTimeSuffixPattern)",
            "大前天|前天|昨天|大后天|后天|明天|今天|明早|明晚|今晚|上午|下午|晚上|早上|中午|凌晨",
            "那天|当天|这天",
            "月底|(?:上上|上|本|这|下下|下)?周末",
            "上上个月|上个月|这个月|这月|下下个月|下个月|上上月|上月|下下月|下月|本月|\(durationNumberPattern)月份?|\(durationNumberPattern)[号日]",
            "\(durationNumberPattern)[:：]\(clockMinutePattern)\(approximateTimeSuffixPattern)|\(durationNumberPattern)点半\(approximateTimeSuffixPattern)|\(durationNumberPattern)点\\s*\(clockMinutePattern)\\s*分?\(approximateTimeSuffixPattern)|\(durationNumberPattern)点钟?\(approximateTimeSuffixPattern)",
            "\(durationNumberPattern)小时\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|过\(durationNumberPattern)分钟|过\(durationNumberPattern)小时|过一会儿|待会儿|待会|一会儿后|一会儿|晚点|稍后",
            "上班前|下班前|睡前|睡觉前|起床后|饭前|饭后|吃饭前|吃饭后",
            "提醒我一下|提醒一下|帮我提醒一下|帮我提醒|提醒我|记得|别忘了|到时候",
            "\(biweeklyRepeatPattern)|每天|每周|每个周|每个星期|每个礼拜|每月|每个月|每隔\(durationNumberPattern)小时|每\(durationNumberPattern)小时|每小时|工作日"
        ]

        for pattern in patterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        if hasDecimalClockTimeExpression(in: input) {
            title = title.replacingOccurrences(
                of: "\\d{1,2}[\\.．]\\d{1,2}\(approximateTimeSuffixPattern)",
                with: "",
                options: .regularExpression
            )
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle == "提醒" ? "" : cleanedTitle
    }

    private func removingFirstOccurrence(of pattern: String, from input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return input
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: nsRange),
              let range = Range(match.range, in: input) else {
            return input
        }

        var output = input
        output.removeSubrange(range)
        return output
    }

    private func missingFields(
        title: String,
        date: Date?,
        isPast: Bool,
        issueFields: [MissingField],
        hasTimeExpression: Bool,
        hasDateExpression: Bool
    ) -> [MissingField] {
        if issueFields == [.unsupportedCondition] {
            return [.unsupportedCondition]
        }

        var fields: [MissingField] = []
        if title.isEmpty {
            fields.append(.title)
        }
        if date == nil {
            if issueFields.contains(.date) || hasDateExpression {
                fields.append(.date)
            }
            if issueFields.contains(.time) || !hasTimeExpression || (!hasDateExpression && !issueFields.contains(.date) && !issueFields.contains(.repeatRule)) {
                fields.append(.time)
            }
        }
        if isPast {
            fields.append(.validFutureTime)
        }

        for field in issueFields where !fields.contains(field) {
            fields.append(field)
        }

        return fields
    }

    private func score(title: String, dateResult: DateParseResult, repeatRule: RepeatRule?, missingFields: [MissingField]) -> Double {
        if !missingFields.isEmpty {
            return 0.45
        }
        if dateResult.hasAmbiguousTime || dateResult.usedDefaultTime {
            return 0.75
        }
        if repeatRule != nil {
            return 0.9
        }
        return title.isEmpty ? 0.3 : 0.95
    }

    private func suggestions(for missingFields: [MissingField], date: Date?) -> [String] {
        if missingFields.contains(.validFutureTime) {
            return ["明天同一时间", "1小时后", "自定义时间"]
        }
        if missingFields.contains(.time) {
            if date != nil {
                return ["当天早上", "当天下午", "当天晚上", "自定义时间"]
            }
            return defaultSuggestions()
        }
        return []
    }

    private func defaultSuggestions() -> [String] {
        ["10分钟后", "30分钟后", "1小时后", "明天早上", "自定义时间"]
    }

    private func firstInteger(before marker: String, in input: String) -> Int? {
        firstMatch(pattern: "(\(durationNumberPattern))\(marker)", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func firstDurationInteger(before marker: String, in input: String) -> Int? {
        firstMatch(pattern: "(\(durationNumberPattern))\(marker)", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func firstDurationInteger(after leadingMarker: String, before trailingMarker: String, in input: String) -> Int? {
        firstMatch(pattern: "\(leadingMarker)(\(durationNumberPattern))\(trailingMarker)", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func durationInteger(from value: String) -> Int? {
        if let integer = Int(value) {
            return integer
        }
        return chineseNumberInteger(from: value)
    }

    private func chineseNumberInteger(from value: String) -> Int? {
        if value.isEmpty {
            return nil
        }

        let digits: [Character: Int] = [
            "零": 0,
            "一": 1,
            "二": 2,
            "两": 2,
            "三": 3,
            "四": 4,
            "五": 5,
            "六": 6,
            "七": 7,
            "八": 8,
            "九": 9
        ]

        if value == "十" {
            return 10
        }

        if let tenIndex = value.firstIndex(of: "十") {
            let prefix = String(value[..<tenIndex])
            let suffix = String(value[value.index(after: tenIndex)...])
            let tens = prefix.isEmpty ? 1 : chineseNumberInteger(from: prefix)
            let ones = suffix.isEmpty ? 0 : chineseNumberInteger(from: suffix)

            guard let tens, let ones else {
                return nil
            }

            return tens * 10 + ones
        }

        if value.count == 1, let digit = value.first.flatMap({ digits[$0] }) {
            return digit
        }

        return nil
    }

    private func firstInteger(after leadingMarker: String, before trailingMarker: String, in input: String) -> Int? {
        firstMatch(pattern: "\(leadingMarker)(\(durationNumberPattern))\(trailingMarker)", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func firstInteger(after marker: String, in input: String) -> Int? {
        firstMatch(pattern: "\(marker)(\(durationNumberPattern))", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func minuteAfterHourMarker(in input: String) -> Int? {
        firstMatch(pattern: "点\\s*(\(clockMinutePattern))\\s*分?", in: input)
            .flatMap { $0.first }
            .flatMap { durationInteger(from: $0) }
    }

    private func firstMatch(pattern: String, in input: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: nsRange), match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: input) else {
                return nil
            }
            return String(input[range])
        }
    }

    private func mondayBasedWeekday(from appleWeekday: Int) -> Int {
        appleWeekday == 1 ? 7 : appleWeekday - 1
    }

    private func adjustedTime(
        hour: Int,
        minute: Int,
        input: String,
        settings: ParserSettings,
        colonStyle: Bool,
        ambiguous: Bool = false
    ) -> (hour: Int, minute: Int, ambiguous: Bool, dayOffset: Int)? {
        guard minute >= 0 && minute <= 59 else {
            return nil
        }

        var adjustedHour = hour
        var dayOffset = 0

        if input.contains("下午") || input.contains("晚上") || input.contains("今晚") || input.contains("明晚") {
            if hour == 12 && input.contains("晚上") {
                adjustedHour = 0
                dayOffset = 1
            } else if hour < 12 {
                adjustedHour = hour + 12
            }
        } else if input.contains("凌晨"), hour == 12 {
            adjustedHour = 0
        }

        guard adjustedHour >= 0 && adjustedHour <= 23 else {
            return nil
        }

        return (adjustedHour, minute, ambiguous && !colonStyle, dayOffset)
    }

    private func parseIssueFields(from input: String) -> [MissingField] {
        var fields: [MissingField] = []

        if occurrenceCount(of: "提醒我", in: input) > 1 {
            return [.unsupportedCondition]
        }

        if hasFutureAbsoluteDayExpression(in: input) && hasRelativeTimeExpression(in: input) {
            fields.append(.time)
        }
        if hasDateConflict(in: input) {
            fields.append(.date)
        }
        if hasInvalidExplicitTimeExpression(in: input) {
            fields.append(.time)
        }
        if hasMultipleTimeExpressions(in: input) {
            fields.append(.time)
        }
        if hasContextualTimeExpression(in: input), !hasTimeExpression(in: input) {
            fields.append(.time)
        }
        if input.contains("之前") || input.contains("回复后") || input.contains("下次") {
            fields.append(.time)
            fields.append(.unsupportedCondition)
        }
        if input.contains("到公司") || input.contains("路过") {
            fields.append(.time)
            fields.append(.unsupportedLocation)
        }
        if input.contains("每2天") ||
            input.contains("隔天") ||
            input.contains("最后一天") ||
            input.range(of: "每周[一二三四五六日天]{2,}", options: .regularExpression) != nil {
            fields.append(.repeatRule)
        }
        if input.contains("农历") {
            fields.append(.time)
        }
        return fields.reduce(into: []) { partialResult, field in
            if !partialResult.contains(field) {
                partialResult.append(field)
            }
        }
    }

    private func shouldInvalidateDate(for issueFields: [MissingField], input: String) -> Bool {
        issueFields.contains(.unsupportedCondition) ||
        issueFields.contains(.unsupportedLocation) ||
        issueFields.contains(.repeatRule) ||
        issueFields.contains(.date) ||
        (issueFields.contains(.time) && !hasContextualTimeExpression(in: input))
    }

    private func hasTimeExpression(in input: String) -> Bool {
        hasDecimalClockTimeExpression(in: input) ||
        input.range(of: "\(durationNumberPattern)[:：]\(durationNumberPattern)|\(durationNumberPattern)点|上午|下午|晚上|早上|中午|凌晨|\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|待会|一会儿", options: .regularExpression) != nil
    }

    private func hasRelativeTimeExpression(in input: String) -> Bool {
        input.range(of: "\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|过\(durationNumberPattern)分钟|过\(durationNumberPattern)小时|过一会儿|待会|一会儿", options: .regularExpression) != nil
    }

    private func hasContextualTimeExpression(in input: String) -> Bool {
        input.range(of: "上班前|下班前|睡前|睡觉前|起床后|饭前|饭后|吃饭前|吃饭后", options: .regularExpression) != nil
    }

    private func hasAbsoluteDayExpression(in input: String) -> Bool {
        input.range(of: "\(namedDateTitlePattern)|\(dotSeparatedMonthDayTitlePattern)|大前天|前天|昨天|今天|明天|后天|大后天|月底|周末|上上周|上周|下下周|下周|本周|这周|上上星期|上星期|下下星期|下星期|本星期|这星期|上上礼拜|上礼拜|下下礼拜|下礼拜|本礼拜|这礼拜|周[一二三四五六日天1-7]|星期[一二三四五六日天1-7]|礼拜[一二三四五六日天1-7]|上上个月|上个月|这个月|这月|下下个月|下个月|上上月|上月|下下月|下月|本月|下个季度|下季度|下半年|大前年|前年|去年|今年|明年|后年|大后年|\\d{4}年|\(durationNumberPattern)月份?|\(durationNumberPattern)[号日]", options: .regularExpression) != nil
    }

    private func hasFutureAbsoluteDayExpression(in input: String) -> Bool {
        input.range(of: "\(namedDateTitlePattern)|\(dotSeparatedMonthDayTitlePattern)|明天|后天|大后天|月底|周末|下下周|下周|本周|这周|下下星期|下星期|本星期|这星期|下下礼拜|下礼拜|本礼拜|这礼拜|周[一二三四五六日天1-7]|星期[一二三四五六日天1-7]|礼拜[一二三四五六日天1-7]|下下个月|下个月|下下月|下月|下个季度|下季度|下半年|明年|后年|大后年|\\d{4}年|\(durationNumberPattern)月份?|\(durationNumberPattern)[号日]", options: .regularExpression) != nil
    }

    private func hasCalendarDateExpression(in input: String) -> Bool {
        input.range(of: "\(namedDateTitlePattern)|\(dotSeparatedMonthDayTitlePattern)|上上个月|上个月|这个月|这月|下下个月|下个月|上上月|上月|下下月|下月|本月|下个季度|下季度|下半年|大前年|前年|去年|今年|明年|后年|大后年|\\d{4}年|\(durationNumberPattern)月份?|\(durationNumberPattern)[号日]", options: .regularExpression) != nil
    }

    private func hasExplicitDateOrTimeExpression(in input: String) -> Bool {
        hasAbsoluteDayExpression(in: input) || hasTimeExpression(in: input)
    }

    private func hasDateConflict(in input: String) -> Bool {
        let relativeDayCount = relativeDayTokenCount(in: input)
        let hasWeekday = input.range(of: "(上上周|上周|下下周|下周|本周|这周)?周[一二三四五六日天1-7]|(上上星期|上星期|下下星期|下星期|本星期|这星期)?星期[一二三四五六日天1-7]|(上上礼拜|上礼拜|下下礼拜|下礼拜|本礼拜|这礼拜)?礼拜[一二三四五六日天1-7]", options: .regularExpression) != nil
        return relativeDayCount > 1 || (relativeDayCount == 1 && hasWeekday)
    }

    private func relativeDayTokenCount(in input: String) -> Int {
        var remaining = input
        var count = 0
        for token in ["大前天", "大后天", "前天", "昨天", "今天", "明天", "后天"] {
            guard !(token == "今天" && weekOffset(in: input) != nil),
                  remaining.contains(token) else {
                continue
            }
            count += 1
            remaining = remaining.replacingOccurrences(of: token, with: "")
        }
        return count
    }

    private func hasMultipleTimeExpressions(in input: String) -> Bool {
        if input.range(of: "\\d{1,2}点.*\\d{1,2}点|\\d{1,2}[:：]\\d{1,2}.*\\d{1,2}[:：]\\d{1,2}", options: .regularExpression) != nil {
            return true
        }
        return decimalClockTimeMatches(in: input).filter { match in
            shouldTreatAsDecimalClockTime(before: match.before)
        }.count > 1
    }

    private func hasInvalidExplicitTimeExpression(in input: String) -> Bool {
        if let match = firstMatch(pattern: "(\(durationNumberPattern))[:：](\(durationNumberPattern))", in: input),
           match.count == 2,
           let hour = durationInteger(from: match[0]),
           let minute = durationInteger(from: match[1]) {
            return hour > 23 || minute > 59
        }

        for match in decimalClockTimeMatches(in: input) {
            if shouldTreatAsDecimalClockTime(before: match.before) {
                return match.hour > 23 || match.minute > 59
            }
        }

        guard let hour = firstInteger(before: "点", in: input) else {
            return false
        }
        if hour > 23 {
            return true
        }
        if let minute = minuteAfterHourMarker(in: input), minute > 59 {
            return true
        }
        return false
    }

    private func hasWeekdayExpression(in input: String) -> Bool {
        weekdayValue(in: input) != nil
    }

    private func hasWeekendExpression(in input: String) -> Bool {
        input.contains("周末")
    }

    private func weekdayValue(in input: String) -> Int? {
        guard let value = firstWeekAnchor(in: input)?.weekdayText else {
            return nil
        }

        return weekdayNumber(from: value)
    }

    private func weekdayNumber(from value: String) -> Int? {
        switch value {
        case "一":
            return 1
        case "二":
            return 2
        case "三":
            return 3
        case "四":
            return 4
        case "五":
            return 5
        case "六":
            return 6
        case "日", "天":
            return 7
        case "1":
            return 1
        case "2":
            return 2
        case "3":
            return 3
        case "4":
            return 4
        case "5":
            return 5
        case "6":
            return 6
        case "7":
            return 7
        default:
            return nil
        }
    }

    private func containsNextQuarterExpression(in input: String) -> Bool {
        input.contains("下个季度") || input.contains("下季度")
    }

    private func containsNextWeekExpression(in input: String) -> Bool {
        weekOffset(in: input) == 1
    }

    private func containsThisWeekExpression(in input: String) -> Bool {
        weekOffset(in: input) == 0
    }

    private func weekOffset(in input: String) -> Int? {
        firstWeekAnchor(in: input)?.offset
    }

    private struct WeekAnchor {
        let offset: Int?
        let weekdayText: String?
    }

    private func firstWeekAnchor(in input: String) -> WeekAnchor? {
        let pattern = "(上上|下下|下一个|下个|上|本|这|下)?(周|星期|礼拜)([一二三四五六日天1-7])?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, range: nsRange)

        for match in matches {
            let modifier = matchedString(at: 1, in: input, match: match)
            let weekday = matchedString(at: 3, in: input, match: match)
            guard modifier != nil || weekday != nil else {
                continue
            }

            return WeekAnchor(offset: weekOffset(from: modifier), weekdayText: weekday)
        }

        return nil
    }

    private func matchedString(at index: Int, in input: String, match: NSTextCheckingResult) -> String? {
        guard match.numberOfRanges > index,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: input) else {
            return nil
        }
        return String(input[range])
    }

    private func weekOffset(from modifier: String?) -> Int? {
        switch modifier {
        case "上上":
            return -2
        case "下下":
            return 2
        case "下一个", "下个":
            return 1
        case "上":
            return -1
        case "本", "这":
            return 0
        case "下":
            return 1
        default:
            return nil
        }
    }

    private func relativeMonthOffset(in input: String) -> Int? {
        if input.contains("上上个月") || input.contains("上上月") {
            return -2
        }
        if input.contains("下下个月") || input.contains("下下月") {
            return 2
        }
        if input.contains("上个月") || input.contains("上月") {
            return -1
        }
        if input.contains("这个月") || input.contains("这月") || input.contains("本月") {
            return 0
        }
        if input.contains("下个月") || input.contains("下月") {
            return 1
        }
        return nil
    }

    private func relativeYearOffset(in input: String) -> Int? {
        if input.contains("大前年") {
            return -3
        }
        if input.contains("大后年") {
            return 3
        }
        if input.contains("前年") {
            return -2
        }
        if input.contains("后年") {
            return 2
        }
        if input.contains("去年") {
            return -1
        }
        if input.contains("今年") {
            return 0
        }
        if input.contains("明年") {
            return 1
        }
        return nil
    }

    private func dayAfterMonth(in input: String) -> Int? {
        firstMatch(pattern: "\(durationNumberPattern)月份?(\(durationNumberPattern))(?:日|号)?", in: input)?
            .first
            .flatMap { durationInteger(from: $0) }
    }

    private func dotSeparatedMonthDay(in input: String) -> DotSeparatedMonthDay? {
        guard let values = firstMatch(pattern: "(?<!\\d)(\\d{1,2})[\\.．](\\d{1,2})\\s*(?:号|日|那天|当天|这天)", in: input),
              values.count == 2,
              let month = Int(values[0]),
              let day = Int(values[1]) else {
            return nil
        }
        return DotSeparatedMonthDay(month: month, day: day)
    }

    private func occurrenceCount(of needle: String, in input: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }

        var count = 0
        var searchRange = input.startIndex..<input.endIndex
        while let range = input.range(of: needle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<input.endIndex
        }
        return count
    }
}
