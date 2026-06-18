import Foundation

protocol DeletedReminderArchiving {
    func append(reminder: Reminder, deletedAt: Date) throws
    func removeRecord(id: UUID) throws
    func removeRecords(ids: Set<UUID>) throws
}

extension DeletedReminderArchiving {
    func removeRecords(ids: Set<UUID>) throws {
        for id in ids {
            try removeRecord(id: id)
        }
    }
}

struct DeletedReminderArchive: DeletedReminderArchiving {
    static let shared = DeletedReminderArchive()

    private let rawFileName = "deleted-reminders.jsonl"
    private let groupedFileName = "deleted-reminders-archive.json"
    private let directoryURL: URL?

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
    }

    func append(reminder: Reminder, deletedAt: Date = Date()) throws {
        let url = try archiveURL()
        let record = DeletedReminderRecord(reminder: reminder, deletedAt: deletedAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)

        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            let offset = try handle.seekToEnd()
            if offset > 0 {
                try handle.write(contentsOf: Data("\n".utf8))
            }
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    func archiveURL() throws -> URL {
        try archiveDirectory().appendingPathComponent(rawFileName)
    }

    func removeRecord(id: UUID) throws {
        try removeRecords(ids: [id])
    }

    func removeRecords(ids: Set<UUID>) throws {
        guard !ids.isEmpty else {
            return
        }

        let url = try archiveURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let records = try deletedRecords()
        let remainingRecords = records.filter { !ids.contains($0.id) }
        guard remainingRecords.count != records.count else {
            return
        }

        if remainingRecords.isEmpty {
            try FileManager.default.removeItem(at: url)
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let lines = try remainingRecords.map { record in
                let data = try encoder.encode(record)
                return String(decoding: data, as: UTF8.self)
            }
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }

        let groupedURL = try archiveDirectory().appendingPathComponent(groupedFileName)
        if FileManager.default.fileExists(atPath: groupedURL.path) {
            try FileManager.default.removeItem(at: groupedURL)
        }
    }

    func groupedArchiveURL(now: Date = Date(), calendar: Calendar = .current) throws -> URL {
        let records = try deletedRecords()
        let groupedRecords = Dictionary(grouping: records) { record in
            ReminderArchivePeriod.period(
                for: record.remindAt,
                now: now,
                calendar: calendar,
                includeOverdue: true
            )
        }
        let groups = ReminderArchivePeriod.archiveExportOrder.map { period in
            DeletedReminderArchiveGroup(
                period: period.rawValue,
                title: period.title,
                count: groupedRecords[period, default: []].count,
                records: groupedRecords[period, default: []]
            )
        }
        let export = DeletedReminderArchiveExport(
            generatedAt: now,
            calendarPolicy: "Gregorian calendar, Monday-start weeks; buckets use nearest natural week, month, quarter, half-year, and year boundaries from generatedAt.",
            groups: groups
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let url = try archiveDirectory().appendingPathComponent(groupedFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func deletedRecords() throws -> [DeletedReminderRecord] {
        let url = try archiveURL()
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try content
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(DeletedReminderRecord.self, from: Data(String(line).utf8))
            }
    }

    private func archiveDirectory() throws -> URL {
        if let directoryURL {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        }

        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct DeletedReminderArchiveExport: Encodable {
    let generatedAt: Date
    let calendarPolicy: String
    let groups: [DeletedReminderArchiveGroup]
}

private struct DeletedReminderArchiveGroup: Encodable {
    let period: String
    let title: String
    let count: Int
    let records: [DeletedReminderRecord]
}

private struct DeletedReminderRecord: Codable {
    let id: UUID
    let title: String
    let tag: String?
    let rawInput: String
    let remindAt: Date
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date
    let notificationId: String
    let parseConfidence: Double
    let repeatType: String
    let repeatInterval: Int
    let repeatWeekday: Int?
    let repeatDayOfMonth: Int?

    init(reminder: Reminder, deletedAt: Date) {
        id = reminder.id
        title = reminder.title
        tag = reminder.tag.rawValue
        rawInput = reminder.rawInput
        remindAt = reminder.remindAt
        status = reminder.status.rawValue
        createdAt = reminder.createdAt
        updatedAt = reminder.updatedAt
        self.deletedAt = deletedAt
        notificationId = reminder.notificationId
        parseConfidence = reminder.parseConfidence
        repeatType = reminder.repeatTypeRaw
        repeatInterval = reminder.repeatInterval
        repeatWeekday = reminder.repeatWeekday
        repeatDayOfMonth = reminder.repeatDayOfMonth
    }
}
