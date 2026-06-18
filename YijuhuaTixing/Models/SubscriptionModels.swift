import Foundation

enum SubscriptionPlan: String, CaseIterable, Codable, Identifiable, Sendable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly:
            return "com.yijuhua.pro.monthly"
        case .quarterly:
            return "com.yijuhua.pro.quarterly"
        case .yearly:
            return "com.yijuhua.pro.annual"
        }
    }

    var displayName: String {
        switch self {
        case .monthly:
            return "月度会员"
        case .quarterly:
            return "季度会员"
        case .yearly:
            return "年度会员"
        }
    }

    var periodText: String {
        switch self {
        case .monthly:
            return "每月"
        case .quarterly:
            return "每季度"
        case .yearly:
            return "每年"
        }
    }

    var fallbackPrice: String {
        "加载中"
    }

    var badgeText: String? {
        switch self {
        case .monthly:
            return nil
        case .quarterly:
            return "推荐"
        case .yearly:
            return "最划算"
        }
    }

    var monthlyHint: String {
        switch self {
        case .monthly:
            return "适合短期尝试"
        case .quarterly:
            return "适合连续使用"
        case .yearly:
            return "长期使用更划算"
        }
    }

    static var productIDs: Set<String> {
        Set(allCases.map(\.productID))
    }
}

struct SubscriptionPlanOption: Identifiable, Equatable, Sendable {
    var id: String { plan.productID }

    let plan: SubscriptionPlan
    let displayPrice: String
    let isStoreProductLoaded: Bool

    var isPurchasable: Bool {
        isStoreProductLoaded
    }
}

struct MembershipEntitlement: Codable, Equatable, Sendable {
    var userID: String?
    var productID: String?
    var originalTransactionID: String?
    var membershipStatus: MembershipStatus
    var expiresAt: Date?
    var trialUsed: Bool
    var autoRenewStatus: Bool?
    var updatedAt: Date

    var grantsProAccess: Bool {
        switch membershipStatus {
        case .trial, .active, .gracePeriod, .billingRetry:
            return true
        case .free, .expired, .revoked:
            return false
        }
    }

    static var free: MembershipEntitlement {
        MembershipEntitlement(
            userID: nil,
            productID: nil,
            originalTransactionID: nil,
            membershipStatus: .free,
            expiresAt: nil,
            trialUsed: false,
            autoRenewStatus: nil,
            updatedAt: Date()
        )
    }

#if DEBUG
    static var debugPro: MembershipEntitlement {
        MembershipEntitlement(
            userID: "debug-user",
            productID: "debug.pro",
            originalTransactionID: "debug-transaction",
            membershipStatus: .active,
            expiresAt: .distantFuture,
            trialUsed: false,
            autoRenewStatus: nil,
            updatedAt: Date()
        )
    }
#endif
}

enum SubscriptionPurchaseOutcome: Equatable, Sendable {
    case purchased(MembershipEntitlement)
    case canceled
    case pending
}

enum SubscriptionError: LocalizedError, Equatable {
    case productUnavailable
    case unverifiedTransaction
    case restoreNotFound

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "会员信息加载失败，请稍后再试。"
        case .unverifiedTransaction:
            return "交易验证失败，请稍后重试。"
        case .restoreNotFound:
            return "没有找到可恢复的购买。"
        }
    }
}
