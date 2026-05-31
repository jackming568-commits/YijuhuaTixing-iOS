import SwiftData
import SwiftUI

@main
struct YijuhuaTixingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Reminder.self)
        } catch {
            print("Failed to create persistent SwiftData container:", error)
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: Reminder.self, configurations: fallbackConfiguration)
            } catch {
                fatalError("Failed to create fallback SwiftData container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
        }
        .modelContainer(modelContainer)
    }
}
