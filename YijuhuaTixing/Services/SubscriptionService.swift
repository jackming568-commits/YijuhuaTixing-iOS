import Foundation
import StoreKit

protocol MembershipEntitlementStoring {
    func loadEntitlement() -> MembershipEntitlement?
    func save(entitlement: MembershipEntitlement)
    func clear()
}

final class UserDefaultsMembershipEntitlementStorage: MembershipEntitlementStoring {
    private let userDefaults: UserDefaults
    private let entitlementKey = "membership.entitlement.v1"
#if DEBUG
    private let debugForceProEntitlementKey = "debug.forceProEntitlement.v2"
#endif
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadEntitlement() -> MembershipEntitlement? {
#if DEBUG
        if userDefaults.bool(forKey: debugForceProEntitlementKey) {
            return .debugPro
        }
#endif
        guard let data = userDefaults.data(forKey: entitlementKey) else {
            return nil
        }
        guard let entitlement = try? decoder.decode(MembershipEntitlement.self, from: data) else {
            return nil
        }
#if DEBUG
        if entitlement.productID == MembershipEntitlement.debugPro.productID {
            clear()
            return nil
        }
#endif
        return entitlement
    }

    func save(entitlement: MembershipEntitlement) {
        guard let data = try? encoder.encode(entitlement) else {
            return
        }
        userDefaults.set(data, forKey: entitlementKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: entitlementKey)
    }
}

protocol SubscriptionServicing {
    func loadPlanOptions() async throws -> [SubscriptionPlanOption]
    func refreshEntitlement() async throws -> MembershipEntitlement
    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws -> MembershipEntitlement
}

final class StoreKitSubscriptionService: SubscriptionServicing {
    private var productsByID: [String: Product] = [:]
    private let storage: MembershipEntitlementStoring

    init(storage: MembershipEntitlementStoring = UserDefaultsMembershipEntitlementStorage()) {
        self.storage = storage
    }

    func loadPlanOptions() async throws -> [SubscriptionPlanOption] {
        let products = try await Product.products(for: SubscriptionPlan.productIDs)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        return SubscriptionPlan.allCases.map { plan in
            let product = productsByID[plan.productID]
            return SubscriptionPlanOption(
                plan: plan,
                displayPrice: product?.displayPrice ?? plan.fallbackPrice,
                isStoreProductLoaded: product != nil
            )
        }
    }

    func refreshEntitlement() async throws -> MembershipEntitlement {
        var bestEntitlement: MembershipEntitlement?

        for await result in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(from: result)
            guard SubscriptionPlan.productIDs.contains(transaction.productID) else {
                continue
            }

            let entitlement = entitlement(from: transaction)
            if isBetter(entitlement, than: bestEntitlement) {
                bestEntitlement = entitlement
            }
        }

        if let bestEntitlement {
            storage.save(entitlement: bestEntitlement)
            return bestEntitlement
        }

        return storage.loadEntitlement() ?? .free
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome {
        guard let product = productsByID[plan.productID] else {
            throw SubscriptionError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            let entitlement = entitlement(from: transaction)
            storage.save(entitlement: entitlement)
            await transaction.finish()
            return .purchased(entitlement)
        case .userCancelled:
            return .canceled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func restorePurchases() async throws -> MembershipEntitlement {
        try await AppStore.sync()
        let entitlement = try await refreshEntitlement()
        guard entitlement.grantsProAccess else {
            throw SubscriptionError.restoreNotFound
        }
        return entitlement
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw SubscriptionError.unverifiedTransaction
        }
    }

    private func entitlement(from transaction: Transaction, now: Date = Date()) -> MembershipEntitlement {
        let status: MembershipStatus
        if transaction.revocationDate != nil {
            status = .revoked
        } else if let expirationDate = transaction.expirationDate, expirationDate <= now {
            status = .expired
        } else {
            status = .active
        }

        return MembershipEntitlement(
            userID: nil,
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            membershipStatus: status,
            expiresAt: transaction.expirationDate,
            trialUsed: false,
            autoRenewStatus: nil,
            updatedAt: now
        )
    }

    private func isBetter(_ entitlement: MembershipEntitlement, than current: MembershipEntitlement?) -> Bool {
        guard let current else {
            return true
        }

        if entitlement.grantsProAccess != current.grantsProAccess {
            return entitlement.grantsProAccess
        }

        return (entitlement.expiresAt ?? .distantFuture) > (current.expiresAt ?? .distantFuture)
    }
}
