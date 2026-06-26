import Foundation
import Observation

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var planOptions: [SubscriptionPlanOption] = SubscriptionPlan.allCases.map {
        SubscriptionPlanOption(plan: $0, displayPrice: $0.fallbackPrice, isStoreProductLoaded: false)
    }
    private(set) var entitlement: MembershipEntitlement = .free
    var isLoadingProducts = false
    var isPurchasing = false
    var errorMessage: String?
    var noticeMessage: String?

    @ObservationIgnored private let service: SubscriptionServicing
    @ObservationIgnored private let analytics: AnalyticsTracking

    var hasProAccess: Bool {
        entitlement.grantsProAccess
    }

    init(
        service: SubscriptionServicing = StoreKitSubscriptionService(),
        analytics: AnalyticsTracking = AppAnalytics.shared
    ) {
        self.service = service
        self.analytics = analytics
    }

    func load(source: String = "settings") async {
        analytics.trackAndFlush(.membershipPageViewed, properties: ["source": source])
        await refreshEntitlement()
        await loadProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        defer { isLoadingProducts = false }

        do {
            planOptions = try await service.loadPlanOptions()
            let loadedCount = planOptions.filter(\.isStoreProductLoaded).count
            if loadedCount > 0 {
                analytics.trackAndFlush(.subscriptionProductLoaded, properties: ["product_count": "\(loadedCount)"])
            } else {
                errorMessage = SubscriptionError.productUnavailable.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        do {
            entitlement = try await service.refreshEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ plan: SubscriptionPlan) async {
        isPurchasing = true
        errorMessage = nil
        noticeMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await service.purchase(plan) {
            case .purchased(let entitlement):
                self.entitlement = entitlement
                noticeMessage = "Pro 会员已生效。"
                analytics.trackAndFlush(.subscriptionPurchased, properties: ["product_id": plan.productID])
            case .canceled:
                noticeMessage = "已取消购买。"
                analytics.trackAndFlush(.subscriptionPurchaseCanceled, properties: ["product_id": plan.productID])
            case .pending:
                noticeMessage = "购买处理中，完成后会自动更新会员状态。"
            }
        } catch {
            errorMessage = error.localizedDescription
            analytics.trackAndFlush(
                .subscriptionPurchaseFailed,
                properties: ["product_id": plan.productID, "reason": error.localizedDescription]
            )
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        noticeMessage = nil
        defer { isPurchasing = false }

        do {
            entitlement = try await service.restorePurchases()
            noticeMessage = "已恢复购买。"
            analytics.trackAndFlush(.subscriptionRestored, properties: ["product_id": entitlement.productID ?? "unknown"])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
