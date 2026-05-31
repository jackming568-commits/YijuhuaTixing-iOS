import Foundation

struct ParserSettings: Codable, Equatable {
    var morningDefaultHour: Int = 9
    var noonDefaultHour: Int = 12
    var afternoonDefaultHour: Int = 15
    var eveningDefaultHour: Int = 20
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

        if let eveningDefaultHour = defaults.object(forKey: "eveningDefaultHour") as? Int {
            settings.eveningDefaultHour = eveningDefaultHour
        }

        return settings
    }
}
