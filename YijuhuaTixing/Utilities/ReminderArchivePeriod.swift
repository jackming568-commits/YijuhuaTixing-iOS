import Foundation

enum ReminderArchivePeriod: String, CaseIterable, Codable, Identifiable {
    case overdue
    case today
    case thisWeek
    case nextWeek
    case thisMonth
    case nextMonth
    case thisQuarter
    case thisHalfYear
    case thisYear
    case twoYears
    case threeYears
    case fourYears
    case fiveYears
    case beyondFiveYears

    var id: String { rawValue }

    static let activeSectionOrder: [ReminderArchivePeriod] = [
        .overdue,
        .today,
        .thisWeek,
        .nextWeek,
        .thisMonth,
        .nextMonth,
        .thisQuarter,
        .thisHalfYear,
        .thisYear,
        .twoYears,
        .threeYears,
        .fourYears,
        .fiveYears,
        .beyondFiveYears
    ]

    static let archiveExportOrder = activeSectionOrder

    var title: String {
        switch self {
        case .overdue:
            return "已过时间"
        case .today:
            return "当天任务"
        case .thisWeek:
            return "本周内任务"
        case .nextWeek:
            return "下周内任务"
        case .thisMonth:
            return "本月内任务"
        case .nextMonth:
            return "下月内任务"
        case .thisQuarter:
            return "本季度内任务"
        case .thisHalfYear:
            return "半年内任务"
        case .thisYear:
            return "本年内任务"
        case .twoYears:
            return "明年内任务"
        case .threeYears:
            return "后年内任务"
        case .fourYears:
            return "四年内任务"
        case .fiveYears:
            return "五年内任务"
        case .beyondFiveYears:
            return "五年后"
        }
    }

    var systemImage: String {
        switch self {
        case .overdue:
            return "exclamationmark.circle.fill"
        case .today:
            return "sun.max"
        case .thisWeek:
            return "calendar.day.timeline.leading"
        case .nextWeek:
            return "calendar.day.timeline.leading"
        case .thisMonth:
            return "calendar"
        case .nextMonth:
            return "calendar"
        case .thisQuarter:
            return "calendar.badge.clock"
        case .thisHalfYear:
            return "calendar.badge.plus"
        case .thisYear:
            return "calendar.circle"
        case .twoYears:
            return "calendar.badge.plus"
        case .threeYears:
            return "calendar.badge.plus"
        case .fourYears:
            return "calendar.badge.plus"
        case .fiveYears:
            return "calendar.badge.plus"
        case .beyondFiveYears:
            return "calendar.badge.exclamationmark"
        }
    }

    var rangeHint: String {
        switch self {
        case .overdue:
            return "已超时"
        case .today:
            return "今天"
        case .thisWeek:
            return "本周"
        case .nextWeek:
            return "下周"
        case .thisMonth:
            return "本月"
        case .nextMonth:
            return "下月"
        case .thisQuarter:
            return "本季度"
        case .thisHalfYear:
            return "本半年"
        case .thisYear:
            return "本年"
        case .twoYears:
            return "明年"
        case .threeYears:
            return "后年"
        case .fourYears:
            return "四年内"
        case .fiveYears:
            return "五年内"
        case .beyondFiveYears:
            return "更远"
        }
    }

    static func period(
        for date: Date,
        now: Date = Date(),
        calendar baseCalendar: Calendar = .current,
        includeOverdue: Bool = false
    ) -> ReminderArchivePeriod {
        let calendar = archiveCalendar(from: baseCalendar)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)

        if includeOverdue, date < now {
            return .overdue
        }

        if startOfDate == startOfToday {
            return .today
        }

        let weekStart = startOfWeek(containing: startOfToday, calendar: calendar)
        let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        if date >= weekStart, date < nextWeekStart {
            return .thisWeek
        }

        let followingWeekStart = calendar.date(byAdding: .day, value: 14, to: weekStart) ?? nextWeekStart
        if date >= nextWeekStart, date < followingWeekStart {
            return .nextWeek
        }

        if isDate(date, inSame: .month, as: startOfToday, calendar: calendar) {
            return .thisMonth
        }

        if isDate(startOfDate, inNext: .month, after: startOfToday, calendar: calendar) {
            return .nextMonth
        }

        if isDate(startOfDate, inSame: .quarter, as: startOfToday, calendar: calendar) {
            return .thisQuarter
        }

        if isDate(startOfDate, inSameHalfYearAs: startOfToday, calendar: calendar) {
            return .thisHalfYear
        }

        if isDate(startOfDate, inSame: .year, as: startOfToday, calendar: calendar) {
            return .thisYear
        }

        let currentYear = calendar.component(.year, from: startOfToday)
        let targetYear = calendar.component(.year, from: startOfDate)

        if targetYear == currentYear + 1 {
            return .twoYears
        }

        if targetYear == currentYear + 2 {
            return .threeYears
        }

        if targetYear == currentYear + 3 {
            return .fourYears
        }

        if targetYear == currentYear + 4 {
            return .fiveYears
        }

        return date < startOfToday ? .overdue : .beyondFiveYears
    }

    static func archiveCalendar(from baseCalendar: Calendar = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = baseCalendar.timeZone
        calendar.locale = baseCalendar.locale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    private static func isDate(
        _ date: Date,
        inSame component: Calendar.Component,
        as startDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard
            let interval = calendar.dateInterval(of: component, for: startDate)
        else {
            return false
        }
        return date >= interval.start && date < interval.end
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: date) ?? date
    }

    private static func isDate(
        _ date: Date,
        inNext component: Calendar.Component,
        after startDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard
            let currentInterval = calendar.dateInterval(of: component, for: startDate),
            let nextStart = calendar.date(byAdding: component, value: 1, to: currentInterval.start),
            let nextInterval = calendar.dateInterval(of: component, for: nextStart)
        else {
            return false
        }
        return date >= nextInterval.start && date < nextInterval.end
    }

    private static func isDate(_ date: Date, inSameHalfYearAs startDate: Date, calendar: Calendar) -> Bool {
        let startMonth = calendar.component(.month, from: startDate)
        let halfStartMonth = startMonth <= 6 ? 1 : 7
        let components = calendar.dateComponents([.year], from: startDate)
        guard
            let year = components.year,
            let halfStart = calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1)),
            let halfEnd = calendar.date(byAdding: .month, value: 6, to: halfStart)
        else {
            return false
        }
        return date >= halfStart && date < halfEnd
    }
}
