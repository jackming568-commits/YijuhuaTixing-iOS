import Foundation

struct ParserSettings: Codable, Equatable {
    var earlyMorningDefaultHour: Int = 2
    var morningDefaultHour: Int = 8
    var morningDefaultMinute: Int = 0
    var forenoonDefaultHour: Int = 10
    var noonDefaultHour: Int = 12
    var afternoonDefaultHour: Int = 14
    var eveningDefaultHour: Int = 19
    var eveningDefaultMinute: Int = 0
    var snoozeDefaultMinutes: Int = 60
    var weekStartsOnMonday: Bool = true
    var localeIdentifier: String = "zh-Hans-CN"
    var timeZoneIdentifier: String = "Asia/Shanghai"

    static let `default` = ParserSettings()

    static func fromUserDefaults(_ defaults: UserDefaults = .standard) -> ParserSettings {
        var settings = ParserSettings.default

        if let morningDefaultHour = defaults.object(forKey: "morningDefaultHour") as? Int {
            settings.morningDefaultHour = morningDefaultHour
        }

        if let morningDefaultMinute = defaults.object(forKey: "morningDefaultMinute") as? Int {
            settings.morningDefaultMinute = normalizedHalfHourMinute(morningDefaultMinute)
        }

        if let eveningDefaultHour = defaults.object(forKey: "eveningDefaultHour") as? Int {
            settings.eveningDefaultHour = eveningDefaultHour
        }

        if let eveningDefaultMinute = defaults.object(forKey: "eveningDefaultMinute") as? Int {
            settings.eveningDefaultMinute = normalizedHalfHourMinute(eveningDefaultMinute)
        }

        return settings
    }

    private static func normalizedHalfHourMinute(_ minute: Int) -> Int {
        minute >= 30 ? 30 : 0
    }
}
