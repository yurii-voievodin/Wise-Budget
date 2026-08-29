import Testing
import Foundation
import Security
@testable import WiseBudget

@MainActor
struct KeychainHelperMigrationTests {

    private let service = "com.wisebudget.test.migration-check"
    private let account = "api-token"

    private func legacyQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func dpQuery() -> [String: Any] {
        var query = legacyQuery()
        query[kSecUseDataProtectionKeychain as String] = true
        return query
    }

    private func readDP() -> String? {
        var query = dpQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @Test func migratesLegacyItemIntoDataProtectionKeychain() throws {
        SecItemDelete(legacyQuery() as CFDictionary)
        SecItemDelete(dpQuery() as CFDictionary)
        defer {
            SecItemDelete(legacyQuery() as CFDictionary)
            SecItemDelete(dpQuery() as CFDictionary)
        }

        var legacyAdd = legacyQuery()
        legacyAdd[kSecValueData as String] = "legacy-token-value".data(using: .utf8)!
        #expect(SecItemAdd(legacyAdd as CFDictionary, nil) == errSecSuccess)

        let migrated = KeychainHelper.loadToken(service: service)
        #expect(migrated == "legacy-token-value")

        #expect(readDP() == "legacy-token-value")
        #expect(KeychainHelper.loadToken(service: service) == "legacy-token-value")
    }

    @Test func saveAndLoadRoundTripsThroughDataProtectionKeychain() throws {
        SecItemDelete(legacyQuery() as CFDictionary)
        SecItemDelete(dpQuery() as CFDictionary)
        defer {
            SecItemDelete(legacyQuery() as CFDictionary)
            SecItemDelete(dpQuery() as CFDictionary)
        }

        try KeychainHelper.save(token: "fresh-token", service: service)
        #expect(readDP() == "fresh-token")
        #expect(KeychainHelper.loadToken(service: service) == "fresh-token")

        try KeychainHelper.deleteToken(service: service)
        #expect(KeychainHelper.loadToken(service: service) == nil)
    }
}
