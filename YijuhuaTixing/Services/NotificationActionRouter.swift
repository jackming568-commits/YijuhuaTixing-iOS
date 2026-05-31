import Foundation
import UserNotifications

enum NotificationActionIdentifier {
    static let category = "REMINDER_CATEGORY"
    static let complete = "REMINDER_COMPLETE"
    static let snooze10m = "REMINDER_SNOOZE_10M"
    static let snooze1h = "REMINDER_SNOOZE_1H"
    static let tomorrowMorning = "REMINDER_TOMORROW_MORNING"
}

enum SnoozeOption: Equatable {
    case minutes(Int)
    case tomorrowMorning

    func targetDate(from now: Date = Date(), calendar: Calendar = .current, settings: ParserSettings = .default) -> Date {
        switch self {
        case .minutes(let minutes):
            return calendar.date(byAdding: .minute, value: minutes, to: now) ?? now
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = settings.morningDefaultHour
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? tomorrow
        }
    }
}

final class NotificationActionRouter {
    static let shared = NotificationActionRouter()

    private enum Action: Equatable {
        case complete(UUID)
        case snooze(UUID, SnoozeOption)
    }

    private struct StoredAction: Codable, Equatable {
        enum Kind: String, Codable {
            case complete
            case snoozeMinutes
            case snoozeTomorrowMorning
        }

        var kind: Kind
        var reminderId: UUID
        var minutes: Int?
    }

    private var onComplete: ((UUID) -> Void)?
    private var onSnooze: ((UUID, SnoozeOption) -> Void)?
    private var pendingActions: [Action] = []
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "NotificationActionRouter.pendingActions"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.pendingActions = Self.loadPendingActions(defaults: defaults, storageKey: storageKey)
    }

    func configure(
        onComplete: @escaping (UUID) -> Void,
        onSnooze: @escaping (UUID, SnoozeOption) -> Void
    ) {
        self.onComplete = onComplete
        self.onSnooze = onSnooze

        let actions = pendingActions
        pendingActions.removeAll()
        savePendingActions()
        actions.forEach(dispatchOrQueue)
    }

    func handle(response: UNNotificationResponse) {
        guard
            response.notification.request.content.categoryIdentifier == NotificationActionIdentifier.category,
            let reminderIdString = response.notification.request.content.userInfo["reminderId"] as? String,
            let reminderId = UUID(uuidString: reminderIdString)
        else {
            return
        }

        handle(actionIdentifier: response.actionIdentifier, reminderId: reminderId)
    }

    func handle(actionIdentifier: String, reminderId: UUID) {
        switch actionIdentifier {
        case NotificationActionIdentifier.complete:
            dispatchOrQueue(.complete(reminderId))
        case NotificationActionIdentifier.snooze10m:
            dispatchOrQueue(.snooze(reminderId, .minutes(10)))
        case NotificationActionIdentifier.snooze1h:
            dispatchOrQueue(.snooze(reminderId, .minutes(60)))
        case NotificationActionIdentifier.tomorrowMorning:
            dispatchOrQueue(.snooze(reminderId, .tomorrowMorning))
        default:
            break
        }
    }

    private func dispatchOrQueue(_ action: Action) {
        switch action {
        case .complete(let reminderId):
            guard let onComplete else {
                queue(action)
                return
            }
            onComplete(reminderId)
        case .snooze(let reminderId, let option):
            guard let onSnooze else {
                queue(action)
                return
            }
            onSnooze(reminderId, option)
        }
    }

    private func queue(_ action: Action) {
        pendingActions.append(action)
        savePendingActions()
    }

    private func savePendingActions() {
        let storedActions = pendingActions.map(Self.storedAction)
        guard let data = try? JSONEncoder().encode(storedActions) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadPendingActions(defaults: UserDefaults, storageKey: String) -> [Action] {
        guard
            let data = defaults.data(forKey: storageKey),
            let storedActions = try? JSONDecoder().decode([StoredAction].self, from: data)
        else {
            return []
        }
        return storedActions.compactMap(Self.action)
    }

    private static func storedAction(from action: Action) -> StoredAction {
        switch action {
        case .complete(let reminderId):
            return StoredAction(kind: .complete, reminderId: reminderId, minutes: nil)
        case .snooze(let reminderId, .minutes(let minutes)):
            return StoredAction(kind: .snoozeMinutes, reminderId: reminderId, minutes: minutes)
        case .snooze(let reminderId, .tomorrowMorning):
            return StoredAction(kind: .snoozeTomorrowMorning, reminderId: reminderId, minutes: nil)
        }
    }

    private static func action(from storedAction: StoredAction) -> Action? {
        switch storedAction.kind {
        case .complete:
            return .complete(storedAction.reminderId)
        case .snoozeMinutes:
            guard let minutes = storedAction.minutes else {
                return nil
            }
            return .snooze(storedAction.reminderId, .minutes(minutes))
        case .snoozeTomorrowMorning:
            return .snooze(storedAction.reminderId, .tomorrowMorning)
        }
    }
}
