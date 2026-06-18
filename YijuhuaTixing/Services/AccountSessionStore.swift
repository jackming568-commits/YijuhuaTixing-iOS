import Foundation
import Observation
import Security

protocol AccountSessionStoring {
    func loadSession() -> AuthSession?
    func loadProfile() -> AccountProfile?
    func save(session: AuthSession, profile: AccountProfile)
    func clear()
}

final class KeychainAccountSessionStorage: AccountSessionStoring {
    private let userDefaults: UserDefaults
    private let service: String
    private let sessionAccount = "auth_session"
    private let profileKey = "account.profile.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard, service: String = "com.yijuhua.tixing.account") {
        self.userDefaults = userDefaults
        self.service = service
    }

    func loadSession() -> AuthSession? {
        var query = sessionQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    func loadProfile() -> AccountProfile? {
        guard let data = userDefaults.data(forKey: profileKey) else {
            return nil
        }
        return try? decoder.decode(AccountProfile.self, from: data)
    }

    func save(session: AuthSession, profile: AccountProfile) {
        saveSession(session)

        guard let data = try? encoder.encode(profile) else {
            return
        }
        userDefaults.set(data, forKey: profileKey)
    }

    func clear() {
        SecItemDelete(sessionQuery() as CFDictionary)
        userDefaults.removeObject(forKey: profileKey)
    }

    private func saveSession(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        SecItemDelete(sessionQuery() as CFDictionary)
        var query = sessionQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private func sessionQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionAccount
        ]
    }
}

final class UserDefaultsAccountSessionStorage: AccountSessionStoring {
    private let userDefaults: UserDefaults
    private let sessionKey = "account.session.v1"
    private let profileKey = "account.profile.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSession() -> AuthSession? {
        load(AuthSession.self, forKey: sessionKey)
    }

    func loadProfile() -> AccountProfile? {
        load(AccountProfile.self, forKey: profileKey)
    }

    func save(session: AuthSession, profile: AccountProfile) {
        save(session, forKey: sessionKey)
        save(profile, forKey: profileKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: sessionKey)
        userDefaults.removeObject(forKey: profileKey)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
@Observable
final class AccountSessionStore {
    private(set) var session: AuthSession?
    private(set) var profile: AccountProfile?
    var isLoading = false
    var errorMessage: String?
    var lastSMSCodeRequestedAt: Date?

    @ObservationIgnored private let authService: any AuthServicing
    @ObservationIgnored private let storage: AccountSessionStoring
    @ObservationIgnored private let analytics: AnalyticsTracking

    var isAuthenticated: Bool {
        session != nil && profile != nil
    }

    var accountStatusText: String {
        profile?.phoneMasked ?? "未登录"
    }

    init(
        authService: any AuthServicing = MockAuthService(),
        storage: AccountSessionStoring = KeychainAccountSessionStorage(),
        analytics: AnalyticsTracking = AppAnalytics.shared
    ) {
        self.authService = authService
        self.storage = storage
        self.analytics = analytics

        let cachedSession = storage.loadSession()
        let cachedProfile = storage.loadProfile()
        if let cachedSession, let cachedProfile {
            session = cachedSession
            profile = cachedProfile
        } else {
            storage.clear()
        }
    }

    @discardableResult
    func requestSMSCode(phoneNumber: String) async -> Bool {
        await perform {
            try await authService.requestSMSCode(phoneNumber: phoneNumber)
            lastSMSCodeRequestedAt = Date()
            analytics.track(.smsCodeRequested, properties: ["method": "phone"])
        }
    }

    @discardableResult
    func login(phoneNumber: String, code: String) async -> Bool {
        await perform {
            let payload = try await authService.verifyCode(phoneNumber: phoneNumber, code: code)
            session = payload.session
            profile = payload.profile
            storage.save(session: payload.session, profile: payload.profile)
            analytics.track(.loginSuccess, properties: ["method": "sms_code"])
        }
    }

    @discardableResult
    func logout() async -> Bool {
        await perform {
            if let session {
                try await authService.logout(session: session)
            }
            clearLocalSession()
            analytics.track(.logout, properties: [:])
        }
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        await perform {
            analytics.track(.accountDeleteRequested, properties: [:])
            if let session {
                try await authService.deleteAccount(session: session)
            }
            clearLocalSession()
            analytics.track(.accountDeleted, properties: [:])
        }
    }

    private func perform(_ operation: () async throws -> Void) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func clearLocalSession() {
        session = nil
        profile = nil
        storage.clear()
    }
}
