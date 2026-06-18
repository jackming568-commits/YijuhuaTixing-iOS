import XCTest
@testable import YijuhuaTixing

final class AnalyticsServiceTests: XCTestCase {
    func testQueuedAnalyticsServicePersistsSanitizedEventWithContext() throws {
        let suiteName = "AnalyticsQueue.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = UserDefaultsAnalyticsEventQueue(userDefaults: userDefaults)
        let adapter = MockThirdPartyAnalyticsAdapter()
        let service = QueuedAnalyticsService(
            queue: queue,
            contextProvider: StaticAnalyticsContextProvider(),
            destination: nil,
            thirdPartyAdapter: adapter
        )
        defer {
            queue.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        service.track(
            .reminderCreated,
            properties: [
                "source": "quick_input",
                "tag": "daily_life",
                "raw_input": "明天提醒我给客户打电话",
                "phone": "13800138000"
            ]
        )

        let record = try XCTUnwrap(queue.loadEvents().first)
        XCTAssertEqual(record.eventName, AnalyticsEvent.reminderCreated.rawValue)
        XCTAssertEqual(record.anonymousID, "anon_test")
        XCTAssertEqual(record.userID, "usr_test")
        XCTAssertEqual(record.membershipStatus, "active")
        XCTAssertEqual(record.properties["source"], "quick_input")
        XCTAssertEqual(record.properties["tag"], "daily_life")
        XCTAssertNil(record.properties["raw_input"])
        XCTAssertNil(record.properties["phone"])
        XCTAssertEqual(adapter.trackedEvents.map(\.event), [.reminderCreated])
        XCTAssertEqual(adapter.identifyCalls.count, 1)
    }

    func testFlushSendsAndRemovesQueuedEvents() async throws {
        let suiteName = "AnalyticsFlush.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = UserDefaultsAnalyticsEventQueue(userDefaults: userDefaults)
        let destination = MockAnalyticsEventDestination()
        let service = QueuedAnalyticsService(
            queue: queue,
            contextProvider: StaticAnalyticsContextProvider(),
            destination: destination
        )
        defer {
            queue.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        service.track(.membershipPageViewed, properties: ["source": "settings"])
        service.track(.tagFilterUsed, properties: ["tag": "health"])

        await service.flush()

        XCTAssertEqual(destination.sentEvents.map(\.eventName), [
            AnalyticsEvent.membershipPageViewed.rawValue,
            AnalyticsEvent.tagFilterUsed.rawValue
        ])
        XCTAssertTrue(queue.loadEvents().isEmpty)
    }

    func testUserDefaultsAnalyticsEventQueueKeepsMostRecentEventsWithinLimit() throws {
        let suiteName = "AnalyticsPrune.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = UserDefaultsAnalyticsEventQueue(userDefaults: userDefaults, maxEvents: 2)
        defer {
            queue.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        queue.append(AnalyticsEventRecord(event: .appOpen, properties: [:], context: StaticAnalyticsContextProvider.context))
        queue.append(AnalyticsEventRecord(event: .sessionStart, properties: [:], context: StaticAnalyticsContextProvider.context))
        queue.append(AnalyticsEventRecord(event: .inputSubmitted, properties: [:], context: StaticAnalyticsContextProvider.context))

        XCTAssertEqual(queue.loadEvents().map(\.eventName), [
            AnalyticsEvent.sessionStart.rawValue,
            AnalyticsEvent.inputSubmitted.rawValue
        ])
    }

    func testAnalyticsConfigurationBuildsEndpointOnlyForHTTPURLs() throws {
        XCTAssertEqual(
            AnalyticsConfiguration.analyticsEndpoint(rawValue: " https://yijuhuatixing.cn/v1/events/batch ")?.absoluteString,
            "https://yijuhuatixing.cn/v1/events/batch"
        )
        XCTAssertEqual(
            AnalyticsConfiguration.analyticsEndpoint(rawValue: "http://localhost:8787/v1/events/batch")?.absoluteString,
            "http://localhost:8787/v1/events/batch"
        )
        XCTAssertNil(AnalyticsConfiguration.analyticsEndpoint(rawValue: ""))
        XCTAssertNil(AnalyticsConfiguration.analyticsEndpoint(rawValue: "file:///tmp/events.json"))
    }
}

private struct StaticAnalyticsContextProvider: AnalyticsContextProviding {
    static let context = AnalyticsContext(
        anonymousID: "anon_test",
        userID: "usr_test",
        sessionID: "ses_test",
        appVersion: "1.0(1)",
        platform: "ios",
        osVersion: "iOS Test",
        membershipStatus: "active",
        channel: "organic",
        campaignID: nil,
        adgroupID: nil,
        creativeID: nil
    )

    func currentContext() -> AnalyticsContext {
        Self.context
    }
}

private final class MockAnalyticsEventDestination: AnalyticsEventDestination {
    private(set) var sentEvents: [AnalyticsEventRecord] = []

    func send(events: [AnalyticsEventRecord]) async throws {
        sentEvents.append(contentsOf: events)
    }
}

private final class MockThirdPartyAnalyticsAdapter: ThirdPartyAnalyticsAdapter {
    private(set) var identifyCalls: [(userID: String?, anonymousID: String)] = []
    private(set) var trackedEvents: [(event: AnalyticsEvent, properties: [String: String])] = []

    func identify(userID: String?, anonymousID: String) {
        identifyCalls.append((userID, anonymousID))
    }

    func track(event: AnalyticsEvent, properties: [String: String], context: AnalyticsContext) {
        trackedEvents.append((event, properties))
    }
}
