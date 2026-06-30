import Foundation

/// The SDK runtime behind the `GleanFeed` facade: holds configuration, the API
/// client, the token store, and the in-memory identity. One instance per
/// `GleanFeed.setup(...)`.
final class GleanFeedClient {
    private let configuration: GleanFeedConfiguration
    private let api: APIClient
    private let tokenStore: TokenStore

    // In-memory identity. `ssoToken` is short-lived + single-use, so it never
    // touches the Keychain. Guarded by `lock` since identify() runs off-thread.
    private let lock = NSLock()
    private var ssoToken: String?
    private var identifiedUserId: String?

    init(configuration: GleanFeedConfiguration, session: URLSession = .shared, tokenStore: TokenStore? = nil) {
        self.configuration = configuration
        self.api = APIClient(baseURL: configuration.baseURL, session: session)
        self.tokenStore = tokenStore ?? KeychainTokenStore(account: configuration.workspaceId)
    }

    var isIdentified: Bool {
        lock.lock(); defer { lock.unlock() }
        return identifiedUserId != nil
    }

    /// The persisted long-lived user token, for cookieless polls (GF-216).
    func userToken() -> String? {
        tokenStore.userToken()
    }

    /// Exchange host-app identity for SDK tokens. On success persists the
    /// long-lived `userToken` (Keychain) and keeps the `ssoToken` in memory.
    func identify(userId: String, email: String?, name: String?, signature: String) async throws {
        let response = try await api.identify(
            IdentifyRequest(
                workspaceId: configuration.workspaceId,
                userId: userId,
                email: email,
                name: name,
                signature: signature
            )
        )

        // Best-effort persist: a Keychain hiccup shouldn't fail an otherwise-good
        // identify — the session still works in memory this launch.
        try? tokenStore.saveUserToken(response.userToken)

        lock.lock()
        ssoToken = response.ssoToken
        identifiedUserId = userId
        lock.unlock()
    }

    /// Clears SDK tokens and in-memory identity. Does NOT touch the host app's
    /// own auth.
    func logout() {
        try? tokenStore.clear()
        lock.lock()
        ssoToken = nil
        identifiedUserId = nil
        lock.unlock()
    }

    /// Resolve the URL to open for a surface. When the user is identified and an
    /// `ssoToken` is available, returns the SSO handoff URL (which mints an
    /// embedded session cookie, then redirects to the surface); otherwise returns
    /// the anonymous surface URL. Fails closed on malformed responses/URLs.
    func surfaceURL(for view: GleanFeedView) async throws -> URL {
        let config = try await api.portalConfig(workspaceSlug: configuration.workspaceSlug, view: view)
        guard let surface = config.surfaces[view.rawValue] else {
            throw GleanFeedError.invalidResponse
        }

        let currentSsoToken: String? = {
            lock.lock(); defer { lock.unlock() }
            return ssoToken
        }()

        guard let ssoToken = currentSsoToken else {
            // Anonymous fallback.
            guard let url = URL(string: surface.url) else { throw GleanFeedError.invalidURL }
            return url
        }

        guard var components = URLComponents(string: config.ssoUrl) else {
            throw GleanFeedError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "token", value: ssoToken),
            URLQueryItem(name: "returnTo", value: surface.returnTo),
        ]
        guard let url = components.url else { throw GleanFeedError.invalidURL }
        return url
    }
}
