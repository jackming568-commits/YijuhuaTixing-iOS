import Foundation

protocol ReminderParsing {
    func parse(_ input: String, now: Date, calendar: Calendar, settings: ParserSettings) -> ParserResult
}

struct LocalReminderParser: ReminderParsing {
    private let durationNumberPattern = "(?:\\d+|[零一二两三四五六七八九十百]+)"

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
        let missingFields = missingFields(
            title: title,
            date: dateResult.date,
            isPast: dateResult.isPast,
            issueFields: issueFields,
            hasTimeExpression: hasTimeExpression(in: normalized)
        )
        let confidence = score(title: title, dateResult: dateResult, repeatRule: repeatRule, missingFields: missingFields)

        let parsed = ParsedReminder(
            title: title,
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

        var baseDate = baseDay(from: input, now: now, calendar: calendar)
        var usedDefaultTime = false
        var ambiguous = false

        if baseDate == nil, let weekdayDate = weekdayDate(from: input, now: now, calendar: calendar) {
            baseDate = weekdayDate
        }

        if baseDate == nil, let monthDate = monthDate(from: input, now: now, calendar: calendar) {
            baseDate = monthDate
        }

        if baseDate == nil, input.contains("月底") {
            baseDate = endOfMonthDate(from: input, now: now, calendar: calendar)
        }

        if baseDate == nil, input.contains("周末") {
            baseDate = weekendDate(from: input, now: now, calendar: calendar)
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
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = fuzzy
            components.minute = 0
            date = calendar.date(from: components) ?? date
            usedDefaultTime = true
        } else if shouldUseDefaultMorning(for: input) {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = settings.morningDefaultHour
            components.minute = 0
            date = calendar.date(from: components) ?? date
            usedDefaultTime = true
        } else if hasContextualTimeExpression(in: input), hasAbsoluteDayExpression(in: input) {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = settings.morningDefaultHour
            components.minute = 0
            date = calendar.date(from: components) ?? date
            usedDefaultTime = true
        } else {
            return DateParseResult(date: nil, isPast: false, usedDefaultTime: false, hasAmbiguousTime: false)
        }

        if date <= now, repeatRule == nil, hasWeekdayExpression(in: input), !containsThisWeekExpression(in: input) {
            date = calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }

        if date <= now,
           repeatRule == nil,
           usedDefaultTime,
           hasWeekendExpression(in: input),
           containsThisWeekExpression(in: input),
           let eveningDate = sameDayDate(as: date, hour: settings.eveningDefaultHour, calendar: calendar),
           eveningDate > now {
            date = eveningDate
        }

        if date <= now, repeatRule == nil, hasWeekendExpression(in: input), !containsThisWeekExpression(in: input) {
            date = nextWeekendDate(keepingTimeFrom: date, after: now, calendar: calendar) ?? date
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
        let referenceDate: Date
        if input.contains("下个月") {
            referenceDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        } else {
            referenceDate = now
        }

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

    private func sameDayDate(as date: Date, hour: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)
    }

    private func baseDay(from input: String, now: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: now)
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

    private func weekdayDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        guard let target = weekdayValue(in: input) else {
            return nil
        }

        let todayMondayBased = mondayBasedWeekday(from: calendar.component(.weekday, from: now))
        var delta = target - todayMondayBased
        if containsThisWeekExpression(in: input) {
            delta = target - todayMondayBased
        } else if containsNextWeekExpression(in: input) {
            let daysUntilNextMonday = 8 - todayMondayBased
            delta = daysUntilNextMonday + target - 1
        } else if delta < 0 {
            delta += 7
        }

        return calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: now))
    }

    private func monthDate(from input: String, now: Date, calendar: Calendar) -> Date? {
        guard let day = firstInteger(before: "号", in: input) ?? dayAfterMonth(in: input) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day

        if input.contains("下个月") {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            components = calendar.dateComponents([.year, .month], from: nextMonth)
            components.day = day
        } else if let explicitMonth = firstInteger(before: "月", in: input), explicitMonth >= 1 && explicitMonth <= 12 {
            components.month = explicitMonth
        }

        return calendar.date(from: components)
    }

    private func explicitTime(from input: String, settings: ParserSettings) -> (hour: Int, minute: Int, ambiguous: Bool, dayOffset: Int)? {
        if let match = firstMatch(pattern: "(\\d{1,2})[:：](\\d{1,2})", in: input), match.count == 2 {
            let hour = Int(match[0]) ?? -1
            let minute = Int(match[1]) ?? -1
            return adjustedTime(hour: hour, minute: minute, input: input, settings: settings, colonStyle: true)
        }

        guard let hour = firstInteger(before: "点", in: input) else {
            return nil
        }

        var minute = 0
        if input.contains("点半") {
            minute = 30
        } else if let value = firstInteger(after: "点", in: input) {
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

    private func fuzzyTime(from input: String, settings: ParserSettings) -> Int? {
        if input.contains("明早") || input.contains("早上") || input.contains("上午") {
            return settings.morningDefaultHour
        }
        if input.contains("凌晨") {
            return 1
        }
        if input.contains("中午") {
            return settings.noonDefaultHour
        }
        if input.contains("下午") {
            return settings.afternoonDefaultHour
        }
        if input.contains("今晚") || input.contains("明晚") || input.contains("晚上") {
            return settings.eveningDefaultHour
        }
        return nil
    }

    private func shouldUseDefaultMorning(for input: String) -> Bool {
        input.contains("号") ||
        input.contains("每周") ||
        input.contains("每个周") ||
        input.contains("每个星期") ||
        input.contains("每个礼拜") ||
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

    private func hourlyInterval(in input: String) -> Int? {
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
        }

        let patterns = [
            "大后天|后天|明天|今天|明早|明晚|今晚|上午|下午|晚上|早上|中午|凌晨",
            "月底|(?:本|这|下)?周末",
            "(下周|本周|这周)?周[一二三四五六日天]|(下星期|本星期|这星期)?星期[一二三四五六日天]|(下礼拜|本礼拜|这礼拜)?礼拜[一二三四五六日天]",
            "下个月|本月|\\d{1,2}月|\\d{1,2}号",
            "\\d{1,2}[:：]\\d{1,2}|\\d{1,2}点半|\\d{1,2}点\\d{1,2}|\\d{1,2}点",
            "\(durationNumberPattern)小时\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|过\(durationNumberPattern)分钟|过\(durationNumberPattern)小时|过一会儿|待会儿|待会|一会儿后|一会儿|晚点|稍后",
            "上班前|下班前|睡前|睡觉前|起床后|饭前|饭后|吃饭前|吃饭后",
            "提醒我|提醒一下|提醒我一下|帮我提醒|记得|别忘了|到时候",
            "每天|每周|每个周|每个星期|每个礼拜|每月|每个月|每隔\(durationNumberPattern)小时|每\(durationNumberPattern)小时|工作日",
            "一下子|一下"
        ]

        for pattern in patterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle == "提醒" ? "" : cleanedTitle
    }

    private func missingFields(
        title: String,
        date: Date?,
        isPast: Bool,
        issueFields: [MissingField],
        hasTimeExpression: Bool
    ) -> [MissingField] {
        if issueFields == [.unsupportedCondition] {
            return [.unsupportedCondition]
        }

        var fields: [MissingField] = []
        if title.isEmpty {
            fields.append(.title)
        }
        if date == nil {
            if issueFields.contains(.date) {
                fields.append(.date)
            }
            if issueFields.contains(.time) || !hasTimeExpression || (!issueFields.contains(.date) && !issueFields.contains(.repeatRule)) {
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
        firstMatch(pattern: "(\\d+)\(marker)", in: input).flatMap { $0.first }.flatMap(Int.init)
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
        firstMatch(pattern: "\(leadingMarker)(\\d+)\(trailingMarker)", in: input).flatMap { $0.first }.flatMap(Int.init)
    }

    private func firstInteger(after marker: String, in input: String) -> Int? {
        firstMatch(pattern: "\(marker)(\\d+)", in: input).flatMap { $0.first }.flatMap(Int.init)
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
        if input.contains("农历") || input.contains("明年") {
            fields.append(.time)
        }
        if input.contains("下个月") && !input.contains("号") && !input.contains("月底") {
            fields.append(.date)
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
        input.range(of: "\\d{1,2}[:：]\\d{1,2}|\\d{1,2}点|上午|下午|晚上|早上|中午|凌晨|\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|待会|一会儿", options: .regularExpression) != nil
    }

    private func hasRelativeTimeExpression(in input: String) -> Bool {
        input.range(of: "\(durationNumberPattern)分钟(?:后|以后)|\(durationNumberPattern)小时(?:后|以后)|过\(durationNumberPattern)分钟|过\(durationNumberPattern)小时|过一会儿|待会|一会儿", options: .regularExpression) != nil
    }

    private func hasContextualTimeExpression(in input: String) -> Bool {
        input.range(of: "上班前|下班前|睡前|睡觉前|起床后|饭前|饭后|吃饭前|吃饭后", options: .regularExpression) != nil
    }

    private func hasAbsoluteDayExpression(in input: String) -> Bool {
        input.range(of: "今天|明天|后天|大后天|月底|周末|下周|本周|这周|下星期|本星期|这星期|下礼拜|本礼拜|这礼拜|周[一二三四五六日天]|星期[一二三四五六日天]|礼拜[一二三四五六日天]|下个月|\\d{1,2}月|\\d{1,2}号", options: .regularExpression) != nil
    }

    private func hasFutureAbsoluteDayExpression(in input: String) -> Bool {
        input.range(of: "明天|后天|大后天|月底|周末|下周|本周|这周|下星期|本星期|这星期|下礼拜|本礼拜|这礼拜|周[一二三四五六日天]|星期[一二三四五六日天]|礼拜[一二三四五六日天]|下个月|\\d{1,2}月|\\d{1,2}号", options: .regularExpression) != nil
    }

    private func hasExplicitDateOrTimeExpression(in input: String) -> Bool {
        hasAbsoluteDayExpression(in: input) || hasTimeExpression(in: input)
    }

    private func hasDateConflict(in input: String) -> Bool {
        let relativeDayCount: Int
        if input.contains("大后天") {
            relativeDayCount = 1
        } else if input.contains("后天") {
            relativeDayCount = 1
        } else {
            relativeDayCount = ["今天", "明天"].filter { input.contains($0) }.count
        }
        let hasWeekday = input.range(of: "(下周|本周|这周)?周[一二三四五六日天]|(下星期|本星期|这星期)?星期[一二三四五六日天]|(下礼拜|本礼拜|这礼拜)?礼拜[一二三四五六日天]", options: .regularExpression) != nil
        return relativeDayCount > 1 || (relativeDayCount == 1 && hasWeekday)
    }

    private func hasMultipleTimeExpressions(in input: String) -> Bool {
        input.range(of: "\\d{1,2}点.*\\d{1,2}点|\\d{1,2}[:：]\\d{1,2}.*\\d{1,2}[:：]\\d{1,2}", options: .regularExpression) != nil
    }

    private func hasWeekdayExpression(in input: String) -> Bool {
        weekdayValue(in: input) != nil
    }

    private func hasWeekendExpression(in input: String) -> Bool {
        input.contains("周末")
    }

    private func weekdayValue(in input: String) -> Int? {
        guard let value = firstMatch(pattern: "(?:每周|每个周|每个星期|每个礼拜|周|星期|礼拜)([一二三四五六日天])", in: input)?.first else {
            return nil
        }

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
        default:
            return nil
        }
    }

    private func containsNextWeekExpression(in input: String) -> Bool {
        input.range(of: "下(?:周|星期|礼拜)", options: .regularExpression) != nil
    }

    private func containsThisWeekExpression(in input: String) -> Bool {
        input.range(of: "(?:本|这)(?:周|星期|礼拜)", options: .regularExpression) != nil
    }

    private func dayAfterMonth(in input: String) -> Int? {
        firstMatch(pattern: "\\d{1,2}月(\\d{1,2})(?:日)?", in: input)?.first.flatMap(Int.init)
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
