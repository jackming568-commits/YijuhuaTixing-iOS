import XCTest
@testable import YijuhuaTixing

final class DeletedReminderArchiveTests: XCTestCase {
    func testRemoveRecordDeletesOnlyMatchingRawArchiveRecordAndGroupedExport() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = DeletedReminderArchive(directoryURL: directory)
        let firstReminder = makeDeletedReminder(title: "删除第一条")
        let secondReminder = makeDeletedReminder(title: "保留第二条")

        try archive.append(reminder: firstReminder, deletedAt: Date())
        try archive.append(reminder: secondReminder, deletedAt: Date())
        let groupedURL = try archive.groupedArchiveURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: groupedURL.path))

        try archive.removeRecord(id: firstReminder.id)

        let content = try String(contentsOf: archive.archiveURL(), encoding: .utf8)
        XCTAssertFalse(content.contains(firstReminder.title))
        XCTAssertTrue(content.contains(secondReminder.title))
        XCTAssertFalse(FileManager.default.fileExists(atPath: groupedURL.path))
    }

    func testRemoveLastRecordDeletesRawArchiveFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = DeletedReminderArchive(directoryURL: directory)
        let reminder = makeDeletedReminder(title: "最后一条")

        try archive.append(reminder: reminder, deletedAt: Date())
        try archive.removeRecord(id: reminder.id)

        let archiveURL = try archive.archiveURL()
        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveURL.path))
    }

    func testRemoveRecordsDeletesMultipleRawArchiveRecords() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = DeletedReminderArchive(directoryURL: directory)
        let firstReminder = makeDeletedReminder(title: "删除第一条")
        let secondReminder = makeDeletedReminder(title: "删除第二条")
        let thirdReminder = makeDeletedReminder(title: "保留第三条")

        try archive.append(reminder: firstReminder, deletedAt: Date())
        try archive.append(reminder: secondReminder, deletedAt: Date())
        try archive.append(reminder: thirdReminder, deletedAt: Date())
        let groupedURL = try archive.groupedArchiveURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: groupedURL.path))

        try archive.removeRecords(ids: Set([firstReminder.id, secondReminder.id]))

        let content = try String(contentsOf: archive.archiveURL(), encoding: .utf8)
        XCTAssertFalse(content.contains(firstReminder.title))
        XCTAssertFalse(content.contains(secondReminder.title))
        XCTAssertTrue(content.contains(thirdReminder.title))
        XCTAssertFalse(FileManager.default.fileExists(atPath: groupedURL.path))
    }

    private func makeDeletedReminder(title: String) -> Reminder {
        Reminder(
            title: title,
            rawInput: title,
            remindAt: Date().addingTimeInterval(600),
            status: .deleted
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "deleted-reminder-archive-\(UUID().uuidString)",
            isDirectory: true
        )
    }
}
