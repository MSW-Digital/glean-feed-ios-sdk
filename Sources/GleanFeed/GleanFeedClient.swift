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
    private var portalOrigins = Set<String>()
    private var portalSessionClearTask: Task<Void, Never>?

    init(
        configuration: GleanFeedConfiguration,
        session: URLSession = .shared,
        tokenStore: TokenStore? = nil
    ) {
        self.configuration = configuration
        self.api = APIClient(baseURL: configuration.baseURL, session: session)
        self.tokenStore = tokenStore ?? KeychainTokenStore(account: configuration.workspaceId)
    }

    var isIdentified: Bool {
    lock.lock()
    defer { lock.unlock() }
        return identifiedUserId != nil
    }

    /// The persisted long-lived user token, for cookieless polls.
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

        // Fail closed: persist the long-lived token BEFORE claiming identity, so we
        // never report `isIdentified == true` with no stored token. A storage
        // failure surfaces as `.storage`.
        try tokenStore.saveUserToken(response.userToken)

        lock.withLock {
            ssoToken = response.ssoToken
            identifiedUserId = userId
        }
    }

    /// Clears SDK tokens and in-memory identity. Does NOT touch the host app's
    /// own auth.
    func logout() {
        // ponytail: clear() failure is swallowed to keep logout non-throwing.
        // In-memory identity is always cleared below; the rare case where the
        // Keychain delete fails (e.g. device locked) leaves the persisted token.
        try? tokenStore.clear()
        let defaultOrigins = defaultPortalOrigins()
        lock.withLock {
            ssoToken = nil
            identifiedUserId = nil
            let origins = portalOrigins.union(defaultOrigins)
            portalOrigins.removeAll()
            portalSessionClearTask = Task { await clearGleanFeedPortalSession(for: origins) }
        }
    }

    /// Unread count for a native badge / "What's new" dot. Signed-in users only —
    /// returns `0` for anonymous users (no stored `userToken`) and for a
    /// stale/invalid token (`401`), so a bad identity never surfaces an error.
    /// Transport/server failures propagate so the caller can leave the badge as-is
    /// (typically via `try?`).
    func unreadCount() async throws -> Int {
        guard let userToken = tokenStore.userToken() else {
            return 0 // anonymous → no badge
        }
        do {
            return try await api.notifications(
                NotificationsRequest(workspaceId: configuration.workspaceId, userToken: userToken)
            ).unreadCount
        } catch GleanFeedError.identityRejected {
            return 0 // stale/invalid token → treat as signed-out, no user-visible error
        }
    }

    /// Send bounded app/device diagnostics for the identified user. No-op if the
    /// user hasn't been identified (no stored `userToken`) — diagnostics are only
    /// ever attributed to a known end user. Best-effort; callers typically ignore
    /// the result.
    func sendDiagnostics() async throws {
        guard let userToken = tokenStore.userToken() else {
            return // no identity → skip cleanly
        }
        try await api.diagnostics(
            DiagnosticsRequest(
                workspaceId: configuration.workspaceId,
                userToken: userToken,
                metadata: DiagnosticsMetadata.current().payload
            )
        )
    }

  var nativeAuthCallbackScheme: String? {
    configuration.callbackURLScheme
  }

  func nativeAuthBridgeRequest(from body: Any) -> NativeAuthBridgeRequest? {
    NativeAuthBridgeRequest(body: body, configuration: configuration)
  }

  func pendingNativeAuth() -> PendingNativeAuth? {
    tokenStore.pendingNativeAuth()
  }

  /// Start a browser/email authorization transaction and persist its device
  /// credential before the external user-agent is shown. A process suspension
  /// or cold launch can therefore resume polling without copying browser cookies.
  func startNativeAuth(_ request: NativeAuthBridgeRequest) async throws -> PendingNativeAuth {
    guard
      let callbackScheme = configuration.callbackURLScheme,
      isValidNativeAuthCallbackScheme(callbackScheme)
    else {
      throw GleanFeedError.nativeAuthNotConfigured
    }

    let codeVerifier = try createNativeAuthCodeVerifier()
    let response = try await api.startNativeAuth(
      NativeAuthStartRequest(
        callbackScheme: callbackScheme,
        codeChallenge: nativeAuthCodeChallenge(codeVerifier),
        email: request.email,
        name: request.name,
        provider: request.provider,
        returnTo: request.returnTo,
        workspaceId: configuration.workspaceId,
        workspaceSlug: configuration.workspaceSlug
      )
    )
    guard response.status == .authorizationPending else {
      throw GleanFeedError.invalidResponse
    }
    if request.provider == .google && response.authorizationUrl == nil {
      throw GleanFeedError.invalidResponse
    }

    let pending = PendingNativeAuth(
      authorizationUrl: response.authorizationUrl,
      authorizationCode: nil,
      callbackResult: nil,
      codeVerifier: codeVerifier,
      expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
      flowId: response.flowId,
      flowSecret: response.flowSecret,
      interval: max(2, min(response.interval, 30)),
      provider: request.provider,
      returnTo: request.returnTo
    )
    try tokenStore.savePendingNativeAuth(pending)
    return pending
  }

  func pollNativeAuth() async throws -> NativeAuthPollOutcome {
    guard let pending = tokenStore.pendingNativeAuth() else {
      throw GleanFeedError.nativeAuthExpired
    }
    guard pending.expiresAt > Date() else {
      try? tokenStore.clearPendingNativeAuth()
      throw GleanFeedError.nativeAuthExpired
    }

    let response = try await api.pollNativeAuth(
      NativeAuthPollRequest(
        authorizationCode: pending.authorizationCode,
        codeVerifier: pending.authorizationCode == nil ? nil : pending.codeVerifier,
        flowId: pending.flowId,
        flowSecret: pending.flowSecret
      )
    )
    switch response.status {
    case .authorizationPending:
      return .pending(interval: max(2, min(response.interval ?? pending.interval, 30)))
    case .failed:
      try? tokenStore.clearPendingNativeAuth()
      throw GleanFeedError.nativeAuthFailed(code: response.code ?? "provider_error")
    case .complete:
      guard let authUrl = response.authUrl else {
        throw GleanFeedError.invalidResponse
      }
      if let userToken = response.userToken {
        // The portal handoff is the primary credential. Do not discard its
        // one-time URL if optional long-lived badge-token persistence fails.
        try? tokenStore.saveUserToken(userToken)
      } else {
        // Team actors do not receive an end-user token. Remove any token left
        // by a previous end-user session so badge/diagnostic calls cannot use
        // the wrong identity after the portal handoff succeeds.
        try? tokenStore.clearUserToken()
      }
      try? tokenStore.clearPendingNativeAuth()
      lock.withLock {
        identifiedUserId = "native:\(pending.flowId)"
      }
      return .complete(authUrl: authUrl)
    }
  }

  func handleNativeAuthCallback(_ url: URL) -> Bool {
    guard let callbackScheme = configuration.callbackURLScheme,
      let callback = parseNativeAuthCallback(url, callbackScheme: callbackScheme),
      let pending = tokenStore.pendingNativeAuth(),
      callback.flowId == pending.flowId
    else { return false }

    let updated = PendingNativeAuth(
      authorizationUrl: pending.authorizationUrl,
      authorizationCode: callback.authorizationCode,
      callbackResult: callback.result,
      codeVerifier: pending.codeVerifier,
      expiresAt: pending.expiresAt,
      flowId: pending.flowId,
      flowSecret: pending.flowSecret,
      interval: pending.interval,
      provider: pending.provider,
      returnTo: pending.returnTo
    )
    do {
      try tokenStore.savePendingNativeAuth(updated)
      return true
    } catch {
      return false
    }
  }

    /// Resolve the URL to open for a surface. On the first call after `identify`,
    /// returns the SSO handoff URL (mints an embedded session cookie, then
    /// redirects to the surface). The `ssoToken` is single-use, so it's consumed
    /// here: later opens return the anonymous surface URL and ride the WebView's
    /// portal session cookie from that first handoff. Fails closed on malformed
    /// responses/URLs.
    func surfaceURL(for view: GleanFeedView) async throws -> URL {
        if let clearTask = lock.withLock({ portalSessionClearTask }) {
            await clearTask.value
        }

        let config = try await api.portalConfig(workspaceSlug: configuration.workspaceSlug, view: view)
        guard let surface = config.surfaces[view.rawValue] else {
            throw GleanFeedError.invalidResponse
        }
        rememberPortalOrigins(from: config)

        // Take the single-use token once, then clear it.
        let currentSsoToken = lock.withLock {
            let token = ssoToken
            ssoToken = nil
            return token
        }

        guard let ssoToken = currentSsoToken else {
            // Anonymous / post-handoff: direct surface URL (rides the session cookie).
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

    private func rememberPortalOrigins(from config: PortalConfigResponse) {
        var origins = Set<String>()
        ([config.portalBaseUrl, config.ssoUrl] + config.surfaces.values.map(\.url)).forEach {
            if let url = URL(string: $0), let origin = gleanFeedOriginKey(url) {
                origins.insert(origin)
            }
        }
        lock.withLock { portalOrigins.formUnion(origins) }
    }

    private func defaultPortalOrigins() -> Set<String> {
        var origins = Set<String>()
        if let apiOrigin = gleanFeedOriginKey(configuration.baseURL) {
            origins.insert(apiOrigin)
        }
        if configuration.baseURL.host?.lowercased() == "gleanfeed.com",
           let url = URL(string: "https://\(configuration.workspaceSlug).gleanfeed.com"),
      let origin = gleanFeedOriginKey(url)
    {
            origins.insert(origin)
        }
        return origins
    }
}
