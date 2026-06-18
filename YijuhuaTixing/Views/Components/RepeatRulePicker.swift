import SwiftUI

struct RepeatRulePicker: View {
    @Binding var repeatRule: RepeatRule

    var body: some View {
        Picker("重复", selection: repeatTypeBinding) {
            ForEach(RepeatRulePickerOption.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
    }

    private var repeatTypeBinding: Binding<RepeatRulePickerOption> {
        Binding(
            get: { RepeatRulePickerOption(repeatRule: repeatRule) },
            set: { option in
                repeatRule = option.repeatRule(
                    preservingWeekday: repeatRule.weekday,
                    preservingDayOfMonth: repeatRule.dayOfMonth
                )
            }
        )
    }
}

private enum RepeatRulePickerOption: String, CaseIterable, Identifiable {
    case none
    case daily
    case hourly
    case weekly
    case biweekly
    case monthly
    case weekdays

    var id: String { rawValue }

    init(repeatRule: RepeatRule) {
        switch repeatRule.type {
        case .none:
            self = .none
        case .daily:
            self = .daily
        case .hourly:
            self = .hourly
        case .weekly:
            self = repeatRule.interval == 2 ? .biweekly : .weekly
        case .monthly:
            self = .monthly
        case .weekdays:
            self = .weekdays
        }
    }

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
        case .biweekly:
            return "每双周"
        case .monthly:
            return "每月"
        case .weekdays:
            return "工作日"
        }
    }

    func repeatRule(preservingWeekday weekday: Int?, preservingDayOfMonth dayOfMonth: Int?) -> RepeatRule {
        switch self {
        case .none:
            return .none
        case .daily:
            return RepeatRule(type: .daily, interval: 1, weekday: weekday, dayOfMonth: dayOfMonth)
        case .hourly:
            return RepeatRule(type: .hourly, interval: 1, weekday: weekday, dayOfMonth: dayOfMonth)
        case .weekly:
            return RepeatRule(type: .weekly, interval: 1, weekday: weekday, dayOfMonth: dayOfMonth)
        case .biweekly:
            return RepeatRule(type: .weekly, interval: 2, weekday: nil, dayOfMonth: nil)
        case .monthly:
            return RepeatRule(type: .monthly, interval: 1, weekday: weekday, dayOfMonth: dayOfMonth)
        case .weekdays:
            return RepeatRule(type: .weekdays, interval: 1, weekday: nil, dayOfMonth: nil)
        }
    }
}
