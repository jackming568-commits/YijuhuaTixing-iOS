import SwiftUI

struct RepeatRulePicker: View {
    @Binding var repeatRule: RepeatRule

    var body: some View {
        Picker("重复", selection: repeatTypeBinding) {
            ForEach(RepeatRuleType.allCases) { type in
                Text(type.displayName).tag(type)
            }
        }
    }

    private var repeatTypeBinding: Binding<RepeatRuleType> {
        Binding(
            get: { repeatRule.type },
            set: { type in
                repeatRule = RepeatRule(type: type, interval: 1, weekday: repeatRule.weekday, dayOfMonth: repeatRule.dayOfMonth)
            }
        )
    }
}
