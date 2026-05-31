import Foundation

enum AnalyticsEvent: String {
    case appOpen = "app_open"
    case inputStarted = "input_started"
    case inputSubmitted = "input_submitted"
    case parseSucceeded = "parse_succeeded"
    case parseFailed = "parse_failed"
    case confirmationShown = "confirmation_shown"
    case reminderConfirmed = "reminder_confirmed"
    case reminderCreated = "reminder_created"
    case notificationPermissionRequested = "notification_permission_requested"
    case notificationPermissionGranted = "notification_permission_granted"
    case notificationPermissionDenied = "notification_permission_denied"
    case reminderCompleted = "reminder_completed"
    case reminderSnoozed = "reminder_snoozed"
    case reminderDeleted = "reminder_deleted"
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

struct ConsoleAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        #if DEBUG
        print("[Analytics]", event.rawValue, properties)
        #endif
    }
}
