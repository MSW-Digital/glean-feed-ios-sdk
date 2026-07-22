import Foundation
import Security

/// Persistence for the long-lived signed SDK user token. The short-lived
/// `ssoToken` is never persisted — it stays in memory only.
protocol TokenStore {
    func saveUserToken(_ token: String) throws
    func userToken() -> String?
    func clearUserToken() throws
    func savePendingNativeAuth(_ pending: PendingNativeAuth) throws
    func pendingNativeAuth() -> PendingNativeAuth?
    func clearPendingNativeAuth() throws
    func clear() throws
}

/// Keychain-backed token store, scoped per workspace. Uses the Security
/// framework directly (no dependency). Accessible after first unlock, this
/// device only — the token never syncs to iCloud.
struct KeychainTokenStore: TokenStore {
    /// Keychain account — the workspace id, so multiple workspaces don't collide.
    let account: String
    let service = "com.gleanfeed.sdk.userToken"
    let nativeAuthService = "com.gleanfeed.sdk.pendingNativeAuth"

    private func baseQuery(service: String? = nil) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? self.service,
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

    func savePendingNativeAuth(_ pending: PendingNativeAuth) throws {
        let query = baseQuery(service: nativeAuthService)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        do {
            attributes[kSecValueData as String] = try JSONEncoder().encode(pending)
        } catch {
            throw GleanFeedError.storage
        }
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw GleanFeedError.storage
        }
    }

    func pendingNativeAuth() -> PendingNativeAuth? {
        var query = baseQuery(service: nativeAuthService)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(PendingNativeAuth.self, from: data)
    }

    func clearPendingNativeAuth() throws {
        let status = SecItemDelete(baseQuery(service: nativeAuthService) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GleanFeedError.storage
        }
    }

    func clearUserToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GleanFeedError.storage
        }
    }

    func clear() throws {
        try clearUserToken()
        try clearPendingNativeAuth()
    }
}
