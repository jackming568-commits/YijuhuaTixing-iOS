import SwiftData

@MainActor
enum AppModelContainer {
    static let shared: ModelContainer = makePersistentContainer()

    private static func makePersistentContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: ReminderSchemaV3.self)
        do {
            return try ModelContainer(for: schema, migrationPlan: ReminderMigrationPlan.self)
        } catch {
            print("Failed to create persistent SwiftData container:", error)
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: ReminderMigrationPlan.self,
                    configurations: fallbackConfiguration
                )
            } catch {
                fatalError("Failed to create fallback SwiftData container: \(error)")
            }
        }
    }
}
