import Foundation

enum AuthError: LocalizedError, Equatable {
    case invalidPhoneNumber
    case smsCodeNotRequested
    case invalidVerificationCode
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "请输入 11 位中国大陆手机号。"
        case .smsCodeNotRequested:
            return "请先获取短信验证码。"
        case .invalidVerificationCode:
            return "验证码不正确。"
        case .notAuthenticated:
            return "登录状态已失效，请重新登录。"
        }
    }
}

protocol AuthServicing {
    func requestSMSCode(phoneNumber: String) async throws
    func verifyCode(phoneNumber: String, code: String) async throws -> AccountAuthPayload
    func refresh(refreshToken: String) async throws -> AccountAuthPayload
    func logout(session: AuthSession) async throws
    func deleteAccount(session: AuthSession) async throws
}

actor MockAuthService: AuthServicing {
    private let mockVerificationCode = "123456"
    private var issuedCodes: [String: String] = [:]
    private var profilesByUserID: [String: AccountProfile] = [:]
    private var phoneByUserID: [String: String] = [:]
    private var userIDByRefreshToken: [String: String] = [:]

    func requestSMSCode(phoneNumber: String) async throws {
        let phone = try normalizedPhone(phoneNumber)
        issuedCodes[phone] = mockVerificationCode
    }

    func verifyCode(phoneNumber: String, code: String) async throws -> AccountAuthPayload {
        let phone = try normalizedPhone(phoneNumber)
        guard let issuedCode = issuedCodes[phone] else {
            throw AuthError.smsCodeNotRequested
        }
        guard code.trimmingCharacters(in: .whitespacesAndNewlines) == issuedCode else {
            throw AuthError.invalidVerificationCode
        }

        let userID = stableUserID(for: phone)
        let profile = profilesByUserID[userID] ?? AccountProfile(
            userID: userID,
            phoneMasked: maskedPhone(phone),
            nickname: nil,
            membershipStatus: .free,
            createdAt: Date()
        )
        profilesByUserID[userID] = profile
        phoneByUserID[userID] = phone
        issuedCodes[phone] = nil

        return AccountAuthPayload(session: makeSession(userID: userID), profile: profile)
    }

    func refresh(refreshToken: String) async throws -> AccountAuthPayload {
        guard
            let userID = userIDByRefreshToken[refreshToken],
            let profile = profilesByUserID[userID]
        else {
            throw AuthError.notAuthenticated
        }
        return AccountAuthPayload(session: makeSession(userID: userID), profile: profile)
    }

    func logout(session: AuthSession) async throws {
        userIDByRefreshToken[session.refreshToken] = nil
    }

    func deleteAccount(session: AuthSession) async throws {
        userIDByRefreshToken[session.refreshToken] = nil
        profilesByUserID[session.userID] = nil
        phoneByUserID[session.userID] = nil
    }

    private func makeSession(userID: String) -> AuthSession {
        let session = AuthSession(
            accessToken: "mock_access_\(UUID().uuidString)",
            refreshToken: "mock_refresh_\(UUID().uuidString)",
            userID: userID
        )
        userIDByRefreshToken[session.refreshToken] = userID
        return session
    }

    private func normalizedPhone(_ phoneNumber: String) throws -> String {
        let phone = phoneNumber.filter(\.isNumber)
        guard phone.count == 11, phone.first == "1" else {
            throw AuthError.invalidPhoneNumber
        }
        return phone
    }

    private func maskedPhone(_ phone: String) -> String {
        "\(phone.prefix(3))****\(phone.suffix(4))"
    }

    private func stableUserID(for phone: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in phone.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "usr_mock_\(String(hash, radix: 16))"
    }
}
