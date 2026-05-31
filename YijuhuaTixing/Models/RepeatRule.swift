import Foundation

enum RepeatRuleType: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case hourly
    case weekly
    case monthly
    case weekdays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "不重复"
        case .daily:
            return "每天"
        case .hourly:
            return "每小时"
        case .weekly:
            return "每周"
        case .monthly:
            return "每月"
        case .weekdays:
            return "工作日"
        }
    }
}

struct RepeatRule: Codable, Equatable {
    var type: RepeatRuleType
    var interval: Int
    var weekday: Int?
    var dayOfMonth: Int?

    static let none = RepeatRule(type: .none, interval: 1, weekday: nil, dayOfMonth: nil)

    var isRepeating: Bool {
        type != .none
    }

    var displayName: String {
        if type == .hourly, interval > 1 {
            return "每\(interval)小时"
        }
        return type.displayName
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch type {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: max(interval, 1), to: date)
        case .hourly:
            return calendar.date(byAdding: .hour, value: max(interval, 1), to: date)
        case .weekly:
            return nextWeeklyDate(after: date, calendar: calendar)
        case .monthly:
            return nextMonthlyDate(after: date, calendar: calendar)
        case .weekdays:
            return nextWeekdayDate(after: date, calendar: calendar)
        }
    }

    private func nextWeeklyDate(after date: Date, calendar: Calendar) -> Date? {
        let targetWeekday = weekday ?? calendar.component(.weekday, from: date)
        var components = DateComponents()
        components.weekday = appleWeekday(fromMondayBased: targetWeekday)
        components.hour = calendar.component(.hour, from: date)
        components.minute = calendar.component(.minute, from: date)
        components.second = 0
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    private func nextMonthlyDate(after date: Date, calendar: Calendar) -> Date? {
        let targetDay = dayOfMonth ?? calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        var cursor = calendar.date(byAdding: .day, value: 1, to: date) ?? date

        for _ in 0..<370 {
            let range = calendar.range(of: .day, in: .month, for: cursor)
            let validDay = min(targetDay, range?.count ?? targetDay)
            var components = calendar.dateComponents([.year, .month], from: cursor)
            components.day = validDay
            components.hour = hour
            components.minute = minute
            components.second = 0

            if let candidate = calendar.date(from: components), candidate > date {
                return candidate
            }

            cursor = calendar.date(byAdding: .month, value: max(interval, 1), to: cursor) ?? cursor
        }

        return nil
    }

    private func nextWeekdayDate(after date: Date, calendar: Calendar) -> Date? {
        var cursor = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        for _ in 0..<10 {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 {
                var components = calendar.dateComponents([.year, .month, .day], from: cursor)
                components.hour = hour
                components.minute = minute
                components.second = 0
                return calendar.date(from: components)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        return nil
    }

    private func appleWeekday(fromMondayBased weekday: Int) -> Int {
        // App rule: 1 = Monday ... 7 = Sunday. Calendar rule: 1 = Sunday ... 7 = Saturday.
        weekday == 7 ? 1 : weekday + 1
    }
}
