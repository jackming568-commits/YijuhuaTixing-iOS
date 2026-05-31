import Foundation
import Observation

@Observable
final class TodayViewModel {
    var inputText = ""
    var isParsing = false
    var parsedReminder: ParsedReminder?
    var errorMessage: String?

    private let parser: ReminderParsing
    private let analytics: AnalyticsTracking
    private let settings: ParserSettings

    init(
        parser: ReminderParsing = LocalReminderParser(),
        analytics: AnalyticsTracking = ConsoleAnalyticsService(),
        settings: ParserSettings = .default
    ) {
        self.parser = parser
        self.analytics = analytics
        self.settings = settings
    }

    func submit(now: Date = Date(), calendar: Calendar = .current, settings overrideSettings: ParserSettings? = nil) {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isParsing = true
        errorMessage = nil
        analytics.track(.inputSubmitted, properties: ["source": "quick_input"])

        let result = parser.parse(input, now: now, calendar: calendar, settings: overrideSettings ?? settings)

        switch result {
        case .success(let parsed), .needsInput(let parsed):
            parsedReminder = parsed
            analytics.track(.parseSucceeded, properties: ["confidence": "\(parsed.confidence)"])
        case .failed(let failure):
            errorMessage = failure.message
            analytics.track(.parseFailed, properties: ["missing": failure.missingFields.map(\.rawValue).joined(separator: ",")])
        }

        isParsing = false
    }

    func resetAfterCreate() {
        inputText = ""
        parsedReminder = nil
        errorMessage = nil
    }
}
