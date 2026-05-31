import Foundation

enum ReminderStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case completed
    case deleted
    case snoozed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "待提醒"
        case .completed:
            return "已完成"
        case .deleted:
            return "已删除"
        case .snoozed:
            return "已延后"
        }
    }
}
