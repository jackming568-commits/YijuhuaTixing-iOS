import Foundation
import Security

enum AnalyticsEvent: String, Codable, Sendable {
    case appInstallDetected = "app_install_detected"
    case appOpen = "app_open"
    case sessionStart = "session_start"
    case onboardingViewed = "onboarding_viewed"
    case inputStarted = "input_started"
    case inputSubmitted = "input_submitted"
    case parseSucceeded = "parse_succeeded"
    case parseFailed = "parse_failed"
    case confirmationShown = "confirmation_shown"
    case reminderConfirmed = "reminder_confirmed"
    case reminderCreated = "reminder_created"
    case notificationPermissionRequested = "notification_permission_requested"
    case notificationPermissionGranted = "notification_permission_granted"
    case notificationPermissionDenied = "notification_permission_denied"
    case notificationPreviewHiddenDetected = "notification_preview_hidden_detected"
    case notificationPreviewHintShown = "notification_preview_hint_shown"
    case testNotificationScheduled = "test_notification_scheduled"
    case reminderCompleted = "reminder_completed"
    case reminderSnoozed = "reminder_snoozed"
    case reminderDeleted = "reminder_deleted"
    case reminderRestored = "reminder_restored"
    case tagFilterUsed = "tag_filter_used"
    case searchUsed = "search_used"
    case smsCodeRequested = "sms_code_requested"
    case smsCodeRequestFailed = "sms_code_request_failed"
    case registerSuccess = "register_success"
    case loginSuccess = "login_success"
    case logout
    case profileUpdated = "profile_updated"
    case passwordSet = "password_set"
    case accountDeleteRequested = "account_delete_requested"
    case accountDeleted = "account_deleted"
    case voiceInputStarted = "voice_input_started"
    case voiceInputResultReceived = "voice_input_result_received"
    case voiceInputFailed = "voice_input_failed"
    case siriReminderCreated = "siri_reminder_created"
    case siriReminderFailed = "siri_reminder_failed"
    case membershipPageViewed = "membership_page_viewed"
    case proFeatureBlocked = "pro_feature_blocked"
    case subscriptionProductLoaded = "subscription_product_loaded"
    case trialStarted = "trial_started"
    case subscriptionPurchased = "subscription_purchased"
    case subscriptionPurchaseCanceled = "subscription_purchase_canceled"
    case subscriptionPurchaseFailed = "subscription_purchase_failed"
    case subscriptionRestored = "subscription_restored"
    case subscriptionExpired = "subscription_expired"
    case subscriptionRenewed = "subscription_renewed"
    case subscriptionCanceled = "subscription_canceled"
    case subscriptionRefunded = "subscription_refunded"
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

protocol AnalyticsReporting: AnalyticsTracking {
    func flush() async
}

struct AnalyticsContext: Codable, Equatable, Sendable {
    var anonymousID: String
    var userID: String?
    var sessionID: String
    var appVersion: String
    var platform: String
    var osVersion: String
    var membershipStatus: String
    var channel: String
    var campaignID: String?
    var adgroupID: String?
    var creativeID: String?
}

struct AnalyticsEventRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String { eventID }

    let eventID: String
    let eventName: String
    let occurredAt: Date
    let anonymousID: String
    let userID: String?
    let sessionID: String
    let appVersion: String
    let platform: String
    let osVersion: String
    let membershipStatus: String
    let channel: String
    let campaignID: String?
    let adgroupID: String?
    let creativeID: String?
    let properties: [String: String]

    init(event: AnalyticsEvent, properties: [String: String], context: AnalyticsContext, occurredAt: Date = Date()) {
        self.eventID = AnalyticsIDFactory.make(prefix: "evt")
        self.eventName = event.rawValue
        self.occurredAt = occurredAt
        self.anonymousID = context.anonymousID
        self.userID = context.userID
        self.sessionID = context.sessionID
        self.appVersion = context.appVersion
        self.platform = context.platform
        self.osVersion = context.osVersion
        self.membershipStatus = context.membershipStatus
        self.channel = context.channel
        self.campaignID = context.campaignID
        self.adgroupID = context.adgroupID
        self.creativeID = context.creativeID
        self.properties = AnalyticsPropertySanitizer.sanitize(properties)
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case eventName = "event_name"
        case occurredAt = "occurred_at"
        case anonymousID = "anonymous_id"
        case userID = "user_id"
        case sessionID = "session_id"
        case appVersion = "app_version"
        case platform
        case osVersion = "os_version"
        case membershipStatus = "membership_status"
        case channel
        case campaignID = "campaign_id"
        case adgroupID = "adgroup_id"
        case creativeID = "creative_id"
        case properties
    }
}

protocol AnalyticsContextProviding {
    func currentContext() -> AnalyticsContext
}

protocol AnalyticsIdentityStoring {
    func loadAnonymousID() -> String?
    func saveAnonymousID(_ id: String)
}

protocol AnalyticsEventQueuing {
    func append(_ event: AnalyticsEventRecord)
    func loadEvents() -> [AnalyticsEventRecord]
    func removeEvents(ids: Set<String>)
    func clear()
}

protocol AnalyticsEventDestination {
    func send(events: [AnalyticsEventRecord]) async throws
}

protocol ThirdPartyAnalyticsAdapter {
    func identify(userID: String?, anonymousID: String)
    func track(event: AnalyticsEvent, properties: [String: String], context: AnalyticsContext)
}

struct AnalyticsIDFactory {
    static func make(prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
    }
}

struct AnalyticsPropertySanitizer {
    private static let blockedKeyFragments = [
        "title",
        "raw_input",
        "rawinput",
        "transcript",
        "phone",
        "password",
        "token",
        "jws",
        "transaction_jws",
        "verification_code"
    ]

    static func sanitize(_ properties: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: properties.compactMap { key, value in
            let normalizedKey = key.lowercased()
            guard blockedKeyFragments.contains(where: { normalizedKey.contains($0) }) == false else {
                return nil
            }

            let safeKey = String(key.prefix(64))
            let safeValue = String(value.prefix(256))
            return (safeKey, safeValue)
        })
    }
}

final class KeychainAnalyticsIdentityStorage: AnalyticsIdentityStoring {
    private let service: String
    private let account = "anonymous_id"

    init(service: String = "com.yijuhua.tixing.analytics") {
        self.service = service
    }

    func loadAnonymousID() -> String? {
        var query = identityQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func saveAnonymousID(_ id: String) {
        guard let data = id.data(using: .utf8) else {
            return
        }

        SecItemDelete(identityQuery() as CFDictionary)
        var query = identityQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private func identityQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class UserDefaultsAnalyticsIdentityStorage: AnalyticsIdentityStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "analytics.anonymous_id.v1") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func loadAnonymousID() -> String? {
        userDefaults.string(forKey: key)
    }

    func saveAnonymousID(_ id: String) {
        userDefaults.set(id, forKey: key)
    }
}

final class UserDefaultsAnalyticsEventQueue: AnalyticsEventQueuing {
    private let userDefaults: UserDefaults
    private let key: String
    private let maxEvents: Int
    private let maxAge: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "analytics.event_queue.v1",
        maxEvents: Int = 500,
        maxAge: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.maxEvents = maxEvents
        self.maxAge = maxAge
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func append(_ event: AnalyticsEventRecord) {
        let events = pruned(loadEvents() + [event])
        save(events)
    }

    func loadEvents() -> [AnalyticsEventRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return (try? decoder.decode([AnalyticsEventRecord].self, from: data)) ?? []
    }

    func removeEvents(ids: Set<String>) {
        save(loadEvents().filter { !ids.contains($0.eventID) })
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }

    private func pruned(_ events: [AnalyticsEventRecord], now: Date = Date()) -> [AnalyticsEventRecord] {
        let freshEvents = events.filter { now.timeIntervalSince($0.occurredAt) <= maxAge }
        if freshEvents.count <= maxEvents {
            return freshEvents
        }
        return Array(freshEvents.suffix(maxEvents))
    }

    private func save(_ events: [AnalyticsEventRecord]) {
        guard let data = try? encoder.encode(events) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

struct DefaultAnalyticsContextProvider: AnalyticsContextProviding {
    private static let sessionID = AnalyticsIDFactory.make(prefix: "ses")

    var identityStorage: AnalyticsIdentityStoring = KeychainAnalyticsIdentityStorage()
    var accountStorage: AccountSessionStoring = KeychainAccountSessionStorage()
    var membershipStorage: MembershipEntitlementStoring = UserDefaultsMembershipEntitlementStorage()
    var bundle: Bundle = .main
    var processInfo: ProcessInfo = .processInfo

    func currentContext() -> AnalyticsContext {
        let anonymousID = loadOrCreateAnonymousID()
        let session = accountStorage.loadSession()
        let profile = accountStorage.loadProfile()
        let membershipStatus = membershipStorage.loadEntitlement()?.membershipStatus.rawValue
            ?? profile?.membershipStatus.rawValue
            ?? MembershipStatus.free.rawValue

        return AnalyticsContext(
            anonymousID: anonymousID,
            userID: session?.userID,
            sessionID: Self.sessionID,
            appVersion: appVersion,
            platform: "ios",
            osVersion: processInfo.operatingSystemVersionString,
            membershipStatus: membershipStatus,
            channel: "organic",
            campaignID: nil,
            adgroupID: nil,
            creativeID: nil
        )
    }

    private var appVersion: String {
        let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String
        switch (shortVersion, build) {
        case (.some(let shortVersion), .some(let build)):
            return "\(shortVersion)(\(build))"
        case (.some(let shortVersion), .none):
            return shortVersion
        default:
            return "0.0"
        }
    }

    private func loadOrCreateAnonymousID() -> String {
        if let anonymousID = identityStorage.loadAnonymousID(), !anonymousID.isEmpty {
            return anonymousID
        }

        let anonymousID = AnalyticsIDFactory.make(prefix: "anon")
        identityStorage.saveAnonymousID(anonymousID)
        return anonymousID
    }
}

struct NoopThirdPartyAnalyticsAdapter: ThirdPartyAnalyticsAdapter {
    func identify(userID: String?, anonymousID: String) {}
    func track(event: AnalyticsEvent, properties: [String: String], context: AnalyticsContext) {}
}

struct HTTPAnalyticsEventDestination: AnalyticsEventDestination {
    struct BatchRequest: Encodable {
        let events: [AnalyticsEventRecord]
    }

    let endpoint: URL
    var urlSession: URLSession = .shared

    func send(events: [AnalyticsEventRecord]) async throws {
        guard !events.isEmpty else {
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(BatchRequest(events: events))

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AnalyticsError.sendFailed
        }
    }
}

enum AnalyticsError: Error {
    case sendFailed
}

struct AnalyticsConfiguration {
    private static let endpointInfoKey = "YIJUHUA_ANALYTICS_ENDPOINT"

    static func makeDestination(bundle: Bundle = .main) -> AnalyticsEventDestination? {
        guard let endpoint = analyticsEndpoint(bundle: bundle) else {
            return nil
        }
        return HTTPAnalyticsEventDestination(endpoint: endpoint)
    }

    static func analyticsEndpoint(bundle: Bundle = .main) -> URL? {
        analyticsEndpoint(rawValue: bundle.object(forInfoDictionaryKey: endpointInfoKey) as? String)
    }

    static func analyticsEndpoint(rawValue: String?) -> URL? {
        guard
            let trimmedValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmedValue.isEmpty == false,
            let url = URL(string: trimmedValue),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return url
    }
}

final class QueuedAnalyticsService: AnalyticsReporting {
    private let queue: AnalyticsEventQueuing
    private let contextProvider: AnalyticsContextProviding
    private let destination: AnalyticsEventDestination?
    private let thirdPartyAdapter: ThirdPartyAnalyticsAdapter

    init(
        queue: AnalyticsEventQueuing = UserDefaultsAnalyticsEventQueue(),
        contextProvider: AnalyticsContextProviding = DefaultAnalyticsContextProvider(),
        destination: AnalyticsEventDestination? = nil,
        thirdPartyAdapter: ThirdPartyAnalyticsAdapter = NoopThirdPartyAnalyticsAdapter()
    ) {
        self.queue = queue
        self.contextProvider = contextProvider
        self.destination = destination
        self.thirdPartyAdapter = thirdPartyAdapter
    }

    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        let context = contextProvider.currentContext()
        let sanitizedProperties = AnalyticsPropertySanitizer.sanitize(properties)
        let record = AnalyticsEventRecord(event: event, properties: sanitizedProperties, context: context)

        queue.append(record)
        thirdPartyAdapter.identify(userID: context.userID, anonymousID: context.anonymousID)
        thirdPartyAdapter.track(event: event, properties: sanitizedProperties, context: context)

        #if DEBUG
        print("[Analytics]", event.rawValue, sanitizedProperties)
        #endif
    }

    func flush() async {
        guard let destination else {
            return
        }

        let events = queue.loadEvents()
        guard !events.isEmpty else {
            return
        }

        do {
            try await destination.send(events: events)
            queue.removeEvents(ids: Set(events.map(\.eventID)))
        } catch {
            #if DEBUG
            print("[Analytics] flush failed", error.localizedDescription)
            #endif
        }
    }
}

enum AppAnalytics {
    static let shared: AnalyticsReporting = QueuedAnalyticsService(destination: AnalyticsConfiguration.makeDestination())
}

struct ConsoleAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        #if DEBUG
        print("[Analytics]", event.rawValue, properties)
        #endif
    }
}
