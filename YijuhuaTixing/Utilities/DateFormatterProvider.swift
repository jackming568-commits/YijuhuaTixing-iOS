import Foundation

enum DateFormatterProvider {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return formatter
    }()

    static func relativeDayLabel(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInTomorrow(date) {
            return "明天"
        }
        return dayFormatter.string(from: date)
    }

    static func overdueLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard date < now else {
            return relativeDayLabel(for: date, calendar: calendar)
        }

        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        if let day = components.day, day > 0 {
            return "已过 \(day) 天"
        }
        if let hour = components.hour, hour > 0 {
            return "已过 \(hour) 小时"
        }

        let minute = max(components.minute ?? 0, 1)
        return "已过 \(minute) 分钟"
    }

    static func snoozedLabel(for date: Date) -> String {
        "已延后到 \(timeFormatter.string(from: date))"
    }
}
