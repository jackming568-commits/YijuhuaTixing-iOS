import Foundation

enum MembershipStatus: String, Codable, Sendable {
    case free
    case trial
    case active
    case gracePeriod = "grace_period"
    case billingRetry = "billing_retry"
    case expired
    case revoked

    var displayName: String {
        switch self {
        case .free:
            return "免费用户"
        case .trial:
            return "试用中"
        case .active:
            return "Pro 会员"
        case .gracePeriod:
            return "宽限期"
        case .billingRetry:
            return "扣费重试中"
        case .expired:
            return "已过期"
        case .revoked:
            return "已撤销"
        }
    }
}

struct AccountProfile: Codable, Equatable, Identifiable, Sendable {
    var id: String { userID }

    let userID: String
    var phoneMasked: String
    var nickname: String?
    var membershipStatus: MembershipStatus
    var createdAt: Date
}

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: String
}

struct AccountAuthPayload: Codable, Equatable, Sendable {
    let session: AuthSession
    let profile: AccountProfile
}
