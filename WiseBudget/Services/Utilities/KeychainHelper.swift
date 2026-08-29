import Foundation
import Security

enum KeychainHelper {
    static let monobankService = "com.wisebudget.monobank-token"
    static let wiseService = "com.wisebudget.wise-token"

    private static let account = "api-token"

    static func save(token: String, service: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        SecItemDelete(baseQuery(service: service, dataProtection: true) as CFDictionary)

        var addQuery = baseQuery(service: service, dataProtection: true)
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status)
        }
    }

    static func loadToken(service: String) -> String? {
        if let token = readToken(service: service, dataProtection: true) {
            return token
        }

        guard let legacyToken = readToken(service: service, dataProtection: false) else {
            return nil
        }

        if (try? save(token: legacyToken, service: service)) != nil {
            SecItemDelete(baseQuery(service: service, dataProtection: false) as CFDictionary)
        }

        return legacyToken
    }

    static func deleteToken(service: String) throws {
        let status = SecItemDelete(baseQuery(service: service, dataProtection: true) as CFDictionary)
        let legacyStatus = SecItemDelete(baseQuery(service: service, dataProtection: false) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
        guard legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound else {
            throw KeychainError.unableToDelete(legacyStatus)
        }
    }

    private static func baseQuery(service: String, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private static func readToken(service: String, dataProtection: Bool) -> String? {
        var query = baseQuery(service: service, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    enum KeychainError: LocalizedError {
        case unableToSave(OSStatus)
        case unableToDelete(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unableToSave(let status):
                return "Unable to save to Keychain (status: \(status))"
            case .unableToDelete(let status):
                return "Unable to delete from Keychain (status: \(status))"
            }
        }
    }
}
