import SwiftData
import SwiftUI

@main
struct YijuhuaTixingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer

    init() {
        modelContainer = AppModelContainer.shared
        AppAnalytics.shared.track(.appOpen, properties: ["launch_type": "cold"])
        AppAnalytics.shared.track(.sessionStart, properties: ["launch_type": "cold"])
        Task {
            await AppAnalytics.shared.flush()
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
        }
        .modelContainer(modelContainer)
    }
}
