import Foundation
import Observation

@Observable
final class ConfirmReminderViewModel {
    private(set) var original: ParsedReminder
    private let settings: ParserSettings
    var title: String
    var tag: ReminderTag
    var addressText: String
    var remindAt: Date
    var repeatRule: RepeatRule
    var didAdjustTime: Bool
    var isCreating = false
    var errorMessage: String?

    init(parsedReminder: ParsedReminder, settings: ParserSettings = .default) {
        self.original = parsedReminder
        self.settings = settings
        self.title = parsedReminder.title
        self.tag = parsedReminder.tag
        self.addressText = parsedReminder.addressText ?? ""
        self.remindAt = parsedReminder.datetime ?? Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        self.repeatRule = parsedReminder.repeatRule ?? .none
        self.didAdjustTime = !Self.requiresTimeEdit(parsedReminder)
    }

    var confirmationTitle: String {
        if requiresTimeSelection {
            return "选择时间"
        }
        return DateFormatterProvider.timeFormatter.string(from: remindAt)
    }

    var confirmationDay: String {
        if requiresTimeSelection {
            return "时间待定"
        }
        return DateFormatterProvider.relativeDayLabel(for: remindAt)
    }

    var titleIsMissing: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAddressText: String {
        addressText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedAddressText: String? {
        trimmedAddressText.isEmpty ? nil : trimmedAddressText
    }

    var hasAddress: Bool {
        normalizedAddressText != nil
    }

    var shouldShowTimeEditorInitially: Bool {
        requiresTimeSelection ||
        original.missingFields.contains(.validFutureTime) ||
        original.missingFields.contains(.unsupportedCondition) ||
        original.missingFields.contains(.unsupportedLocation) ||
        original.missingFields.contains(.repeatRule) ||
        remindAt <= Date()
    }

    var timeNeedsAttention: Bool {
        requiresTimeSelection ||
        !didAdjustTime ||
        remindAt <= Date()
    }

    var timeSummary: String {
        if requiresTimeSelection {
            return "请选择时间"
        }
        return "\(confirmationDay) \(confirmationTitle)"
    }

    var titlePlaceholder: String {
        if titleIsMissing {
            return "补一句要提醒的事"
        }
        return "要提醒你做什么？"
    }

    var primaryButtonTitle: String {
        if titleIsMissing {
            return "补充提醒内容后确认"
        }

        if timeNeedsAttention {
            return "选择未来时间后确认"
        }

        return "确认提醒"
    }

    @discardableResult
    func applySuggestion(_ suggestion: String) -> Bool {
        if let time = anchoredSuggestionTime(for: suggestion),
           let anchoredDate = original.datetime {
            remindAt = date(onSameDayAs: anchoredDate, hour: time.hour, minute: time.minute)
            didAdjustTime = true
            return true
        }

        let option: SnoozeOption
        switch suggestion {
        case "10分钟后":
            option = .minutes(10)
        case "30分钟后":
            option = .minutes(30)
        case "1小时后":
            option = .minutes(60)
        case "明天早上":
            option = .tomorrowMorning
        default:
            return false
        }

        remindAt = option.targetDate(settings: settings)
        didAdjustTime = true
        return true
    }

    private func anchoredSuggestionTime(for suggestion: String) -> (hour: Int, minute: Int)? {
        switch suggestion {
        case "当天早上":
            return (settings.morningDefaultHour, settings.morningDefaultMinute)
        case "当天下午":
            return (settings.afternoonDefaultHour, 0)
        case "当天晚上":
            return (settings.eveningDefaultHour, settings.eveningDefaultMinute)
        default:
            return nil
        }
    }

    private func date(onSameDayAs date: Date, hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    func updateRemindAt(_ date: Date) {
        remindAt = date
        didAdjustTime = true
    }

    var canConfirm: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        didAdjustTime &&
        remindAt > Date()
    }

    private var requiresTimeSelection: Bool {
        !didAdjustTime && (original.datetime == nil || original.missingFields.contains(.time))
    }

    var validationMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "补一句要提醒的事。"
        }

        if original.missingFields.contains(.unsupportedLocation) {
            return "地点提醒第一版还不支持，先改成一个明确时间。"
        }

        if original.missingFields.contains(.repeatRule) {
            return "这个重复规则第一版还不支持，先改成单次提醒或基础重复。"
        }

        if original.missingFields.contains(.unsupportedCondition) {
            return "这句话像是条件提醒，先拆成一条明确时间的提醒。"
        }

        if original.missingFields.contains(.date) || original.missingFields.contains(.time) {
            return "请选择一个明确的未来时间。"
        }

        if original.missingFields.contains(.validFutureTime) || remindAt <= Date() {
            return "这个时间已经过去，请改到未来时间。"
        }

        if !didAdjustTime {
            return "确认前先检查一下提醒时间。"
        }

        return nil
    }

    func buildParsedReminder() -> ParsedReminder {
        ParsedReminder(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            tag: tag,
            addressText: normalizedAddressText,
            datetime: remindAt,
            repeatRule: repeatRule.type == .none ? nil : repeatRule,
            confidence: original.confidence,
            needsUserConfirmation: true,
            missingFields: [],
            rawInput: original.rawInput,
            parseSource: original.parseSource,
            suggestions: original.suggestions
        )
    }

    private static func requiresTimeEdit(_ parsedReminder: ParsedReminder) -> Bool {
        parsedReminder.datetime == nil ||
        parsedReminder.missingFields.contains(.date) ||
        parsedReminder.missingFields.contains(.time) ||
        parsedReminder.missingFields.contains(.validFutureTime) ||
        parsedReminder.missingFields.contains(.unsupportedCondition) ||
        parsedReminder.missingFields.contains(.unsupportedLocation) ||
        parsedReminder.missingFields.contains(.repeatRule)
    }
}
