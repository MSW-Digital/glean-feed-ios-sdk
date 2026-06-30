import Foundation
import Security

/// Persistence for the long-lived signed SDK user token. The short-lived
/// `ssoToken` is never persisted — it stays in memory only.
protocol TokenStore {
    func saveUserToken(_ token: String) throws
    func userToken() -> String?
    func clear() throws
}

/// Keychain-backed token store, scoped per workspace. Uses the Security
/// framework directly (no dependency). Accessible after first unlock, this
/// device only — the token never syncs to iCloud.
struct KeychainTokenStore: TokenStore {
    /// Keychain account — the workspace id, so multiple workspaces don't collide.
    let account: String
    let service = "com.gleanfeed.sdk.userToken"

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func saveUserToken(_ token: String) throws {
        // Idempotent overwrite: delete any existing item, then add.
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw GleanFeedError.storage }
    }

    func userToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return token
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GleanFeedError.storage
        }
    }
}
