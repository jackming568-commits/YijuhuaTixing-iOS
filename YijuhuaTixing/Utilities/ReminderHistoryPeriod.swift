import Foundation

enum ReminderHistoryPeriod: String, CaseIterable, Codable, Identifiable {
    case today
    case thisWeek
    case thisMonth
    case thisQuarter
    case thisHalfYear
    case thisYear
    case twoYears
    case threeYears
    case fiveYears

    var id: String { rawValue }

    static let sectionOrder: [ReminderHistoryPeriod] = [
        .today,
        .thisWeek,
        .thisMonth,
        .thisQuarter,
        .thisHalfYear,
        .thisYear,
        .twoYears,
        .threeYears,
        .fiveYears
    ]

    var title: String {
        switch self {
        case .today:
            return "当天内已完成任务"
        case .thisWeek:
            return "本周内已完成任务"
        case .thisMonth:
            return "本月内已完成任务"
        case .thisQuarter:
            return "本季度内已完成任务"
        case .thisHalfYear:
            return "半年内已完成任务"
        case .thisYear:
            return "今年内已完成任务"
        case .twoYears:
            return "去年内已完成任务"
        case .threeYears:
            return "前年内已完成任务"
        case .fiveYears:
            return "五年内已完成任务"
        }
    }

    var rangeHint: String {
        switch self {
        case .today:
            return "今天完成"
        case .thisWeek:
            return "本周完成"
        case .thisMonth:
            return "本月完成"
        case .thisQuarter:
            return "本季度完成"
        case .thisHalfYear:
            return "本半年完成"
        case .thisYear:
            return "今年完成"
        case .twoYears:
            return "去年完成"
        case .threeYears:
            return "前年完成"
        case .fiveYears:
            return "近5年"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "checkmark.circle.fill"
        case .thisWeek:
            return "calendar.day.timeline.leading"
        case .thisMonth:
            return "calendar"
        case .thisQuarter:
            return "calendar.badge.clock"
        case .thisHalfYear:
            return "calendar.badge.plus"
        case .thisYear:
            return "calendar.circle"
        case .twoYears, .threeYears, .fiveYears:
            return "calendar.badge.checkmark"
        }
    }

    static func period(
        for date: Date,
        now: Date = Date(),
        calendar baseCalendar: Calendar = .current
    ) -> ReminderHistoryPeriod? {
        let calendar = ReminderArchivePeriod.archiveCalendar(from: baseCalendar)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)

        guard date <= now else {
            return nil
        }

        if startOfDate == startOfToday {
            return .today
        }

        let weekStart = startOfWeek(containing: startOfToday, calendar: calendar)
        let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        if date >= weekStart, date < nextWeekStart {
            return .thisWeek
        }

        if isDate(date, inSame: .month, as: startOfToday, calendar: calendar) {
            return .thisMonth
        }

        let quarterStart = startOfQuarter(containing: startOfToday, calendar: calendar)
        let nextQuarterStart = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? quarterStart
        if date >= quarterStart, date < nextQuarterStart {
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

        if targetYear == currentYear - 1 {
            return .twoYears
        }

        if targetYear == currentYear - 2 {
            return .threeYears
        }

        if targetYear >= currentYear - 4, targetYear < currentYear - 2 {
            return .fiveYears
        }

        return nil
    }

    static func isWithinFiveYears(
        _ date: Date,
        now: Date = Date(),
        calendar baseCalendar: Calendar = .current
    ) -> Bool {
        period(for: date, now: now, calendar: baseCalendar) != nil
    }

    private static func isDate(
        _ date: Date,
        inSame component: Calendar.Component,
        as startDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let interval = calendar.dateInterval(of: component, for: startDate) else {
            return false
        }
        return date >= interval.start && date < interval.end
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: date) ?? date
    }

    private static func startOfQuarter(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? calendar.component(.year, from: date)
        let month = components.month ?? calendar.component(.month, from: date)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        return calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1)) ?? date
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
