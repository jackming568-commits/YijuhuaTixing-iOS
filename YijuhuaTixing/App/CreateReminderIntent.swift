import AppIntents
import Foundation

struct CreateReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "创建一句话提醒"
    static var description = IntentDescription("用一句话创建提醒任务。")
    static var openAppWhenRun = false

    @Parameter(title: "提醒内容")
    var reminderText: String

    static var parameterSummary: some ParameterSummary {
        Summary("创建提醒 \(\.$reminderText)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await ShortcutReminderCreationService(
            container: AppModelContainer.shared,
            settings: ParserSettings.fromUserDefaults()
        ).createReminder(from: reminderText)

        return .result(dialog: IntentDialog(stringLiteral: result.dialog))
    }
}

struct YijuhuaTixingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: [
                "\(.applicationName)创建提醒",
                "\(.applicationName)创建一句话提醒",
                "用\(.applicationName)创建提醒",
                "用\(.applicationName)创建一句话提醒",
                "让\(.applicationName)创建提醒",
                "通过\(.applicationName)创建提醒",
                "在\(.applicationName)里创建提醒"
            ],
            shortTitle: "创建提醒",
            systemImageName: "bell.badge"
        )
    }
}
