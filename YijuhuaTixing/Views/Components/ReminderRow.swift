import SwiftUI

struct ReminderRow: View {
    var reminder: Reminder
    var onComplete: () -> Void
    var onDelete: () -> Void
    var onSnooze: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DateFormatterProvider.timeFormatter.string(from: reminder.remindAt))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(timeColor)
                Text(dayStatusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.body)
                    .lineLimit(2)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? Color.secondary : Color.primary)

                HStack(spacing: 6) {
                    ReminderTagChip(tag: reminder.tag)

                    if isOverdue {
                        Label("提醒时间已过", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if isSnoozed {
                        Label(DateFormatterProvider.snoozedLabel(for: reminder.remindAt), systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if reminder.repeatRule.isRepeating {
                        Label(reminder.repeatRule.displayName, systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)

                if shouldShowRawInputHint {
                    Text(reminder.rawInput)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onLongPressGesture(perform: onSnooze)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点查看详情，左滑稍后或删除，右滑完成")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }

            Button(action: onSnooze) {
                Label("稍后", systemImage: "clock.arrow.circlepath")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onComplete) {
                Label("完成", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    private var isOverdue: Bool {
        reminder.status != .completed && reminder.remindAt < Date()
    }

    private var isSnoozed: Bool {
        reminder.status == .snoozed
    }

    private var timeColor: Color {
        if isOverdue {
            return .orange
        }
        if isSnoozed {
            return .blue
        }
        return .primary
    }

    private var statusColor: Color {
        if isOverdue {
            return .orange
        }
        if isSnoozed {
            return .blue
        }
        return .secondary
    }

    private var dayStatusLabel: String {
        if isOverdue {
            return DateFormatterProvider.overdueLabel(for: reminder.remindAt)
        }
        if isSnoozed {
            return "已延后"
        }
        return DateFormatterProvider.relativeDayLabel(for: reminder.remindAt)
    }

    private var shouldShowRawInputHint: Bool {
        let rawInput = reminder.rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty, rawInput != reminder.title else {
            return false
        }
        return reminder.title.count <= 2 || reminder.parseConfidence < 0.8
    }
}
