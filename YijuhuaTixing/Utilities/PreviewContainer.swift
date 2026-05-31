import Foundation
import SwiftData

enum PreviewContainer {
    @MainActor
    static var inMemory: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Reminder.self, configurations: config)
            let sample = Reminder(
                title: "给客户发报价",
                rawInput: "明天上午10点提醒我给客户发报价",
                remindAt: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                parseConfidence: 0.95
            )
            let overdue = Reminder(
                title: "回客户电话",
                rawInput: "半小时前提醒我回客户电话",
                remindAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
                parseConfidence: 0.9
            )
            container.mainContext.insert(sample)
            container.mainContext.insert(overdue)
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
