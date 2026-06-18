import XCTest
@testable import YijuhuaTixing

final class SubscriptionServiceTests: XCTestCase {
    func testProductIDsMatchSubscriptionContract() {
        XCTAssertEqual(SubscriptionPlan.monthly.productID, "com.yijuhua.pro.monthly")
        XCTAssertEqual(SubscriptionPlan.quarterly.productID, "com.yijuhua.pro.quarterly")
        XCTAssertEqual(SubscriptionPlan.yearly.productID, "com.yijuhua.pro.annual")
        XCTAssertEqual(SubscriptionPlan.quarterly.badgeText, "推荐")
        XCTAssertEqual(SubscriptionPlan.yearly.badgeText, "最划算")
    }

    func testFallbackCopyDoesNotHardcodeCurrency() {
        for plan in SubscriptionPlan.allCases {
            XCTAssertFalse(plan.fallbackPrice.contains("¥"))
            XCTAssertFalse(plan.monthlyHint.contains("¥"))
        }
    }

    func testMembershipEntitlementProAccessRules() {
        var entitlement = MembershipEntitlement.free
        XCTAssertFalse(entitlement.grantsProAccess)

        entitlement.membershipStatus = .trial
        XCTAssertTrue(entitlement.grantsProAccess)

        entitlement.membershipStatus = .active
        XCTAssertTrue(entitlement.grantsProAccess)

        entitlement.membershipStatus = .expired
        XCTAssertFalse(entitlement.grantsProAccess)

        entitlement.membershipStatus = .revoked
        XCTAssertFalse(entitlement.grantsProAccess)
    }

    func testMembershipStorageSavesAndClearsEntitlement() throws {
        let suiteName = "MembershipStorage.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let storage = UserDefaultsMembershipEntitlementStorage(userDefaults: userDefaults)
        defer {
            storage.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let entitlement = MembershipEntitlement(
            userID: "usr_test",
            productID: SubscriptionPlan.yearly.productID,
            originalTransactionID: "2000000000000001",
            membershipStatus: .active,
            expiresAt: Date(timeIntervalSince1970: 2_000),
            trialUsed: true,
            autoRenewStatus: true,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        storage.save(entitlement: entitlement)

        XCTAssertEqual(storage.loadEntitlement(), entitlement)

        storage.clear()

        XCTAssertNil(storage.loadEntitlement())
    }

#if DEBUG
    func testMembershipStorageDropsStaleDebugEntitlement() throws {
        let suiteName = "MembershipStorage.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let storage = UserDefaultsMembershipEntitlementStorage(userDefaults: userDefaults)
        defer {
            storage.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        storage.save(entitlement: .debugPro)

        XCTAssertNil(storage.loadEntitlement())
    }
#endif
}
