import XCTest
@testable import YijuhuaTixing

final class AuthServiceTests: XCTestCase {
    func testKeychainStorageSavesAndClearsSession() throws {
        let suiteName = "AccountStorage.\(UUID().uuidString)"
        let service = "com.yijuhua.tixing.tests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let storage = KeychainAccountSessionStorage(userDefaults: userDefaults, service: service)
        defer {
            storage.clear()
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userID: "usr_test"
        )
        let profile = AccountProfile(
            userID: "usr_test",
            phoneMasked: "138****8000",
            nickname: nil,
            membershipStatus: .free,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        storage.save(session: session, profile: profile)

        XCTAssertEqual(storage.loadSession(), session)
        XCTAssertEqual(storage.loadProfile(), profile)

        storage.clear()

        XCTAssertNil(storage.loadSession())
        XCTAssertNil(storage.loadProfile())
    }

    func testMockLoginCreatesFreeProfile() async throws {
        let service = MockAuthService()

        try await service.requestSMSCode(phoneNumber: "13800138000")
        let payload = try await service.verifyCode(phoneNumber: "13800138000", code: "123456")

        XCTAssertEqual(payload.profile.phoneMasked, "138****8000")
        XCTAssertEqual(payload.profile.membershipStatus, .free)
        XCTAssertEqual(payload.session.userID, payload.profile.userID)
        XCTAssertTrue(payload.session.accessToken.hasPrefix("mock_access_"))
        XCTAssertTrue(payload.session.refreshToken.hasPrefix("mock_refresh_"))
    }

    func testMockLoginRequiresRequestedCode() async throws {
        let service = MockAuthService()

        do {
            _ = try await service.verifyCode(phoneNumber: "13800138000", code: "123456")
            XCTFail("Expected verifyCode to require a requested SMS code.")
        } catch {
            XCTAssertEqual(error as? AuthError, .smsCodeNotRequested)
        }
    }

    func testMockLoginRejectsInvalidCode() async throws {
        let service = MockAuthService()
        try await service.requestSMSCode(phoneNumber: "13800138000")

        do {
            _ = try await service.verifyCode(phoneNumber: "13800138000", code: "000000")
            XCTFail("Expected verifyCode to reject an invalid code.")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidVerificationCode)
        }
    }
}
