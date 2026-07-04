import Foundation

/// Glean Feed iOS SDK — **beta**.
///
/// Presents hosted Glean Feed feedback, roadmap, and changelog surfaces inside a
/// native `WKWebView`, backed by server-signed end-user identity.
///
/// ```swift
/// GleanFeed.setup(workspaceId: "workspace-uuid", workspaceSlug: "acme")
/// try await GleanFeed.identify(userId: "u1", email: "a@b.com", signature: sigFromServer)
/// GleanFeed.showFeedback()
/// ```
///
/// The SDK handles configuration, identity exchange, token storage, hosted
/// surface presentation, unread counts, and bounded diagnostics.
public enum GleanFeed {
    /// The SDK version. Beta: the public API may change before `1.0.0`.
    public static let version = "0.1.2"

    /// The runtime created by `setup`. Internal so tests can inject a client
    /// built with a mocked `URLSession` / token store. Set once in `setup` (call
    /// early, before use); revisit isolation at the Swift 6 language-mode migration.
    static var shared: GleanFeedClient?

    /// Configure the SDK. Call once, early (e.g. in `application(_:didFinishLaunchingWithOptions:)`).
    ///
    /// - Parameters:
    ///   - workspaceId: Your Glean Feed workspace UUID (used to sign identity).
    ///   - workspaceSlug: Your workspace slug (used to resolve portal URLs).
    ///   - environment: Which backend to talk to. Defaults to `.production`.
    public static func setup(
        workspaceId: String,
        workspaceSlug: String,
        environment: GleanFeedEnvironment = .production
    ) {
        shared = GleanFeedClient(
            configuration: GleanFeedConfiguration(
                workspaceId: workspaceId,
                workspaceSlug: workspaceSlug,
                baseURL: environment.baseURL
            )
        )
    }

    /// Identify the current end user. `signature` is an HMAC computed on YOUR
    /// backend with the workspace secret — never in the app. Omit identity to
    /// browse anonymously. Throws ``GleanFeedError`` on failure; callers may
    /// ignore the error to fall back to anonymous browsing.
    public static func identify(
        userId: String,
        email: String? = nil,
        name: String? = nil,
        signature: String
    ) async throws {
        try await requireClient().identify(
            userId: userId,
            email: email,
            name: name,
            signature: signature
        )
    }

    /// Clear SDK tokens and in-memory identity. Does not affect the host app's
    /// own authentication. No-op if `setup` was never called.
    public static func logout() {
        shared?.logout()
    }

    /// Unread notification count for a native badge / "What's new" indicator.
    /// Signed-in users only: returns `0` when `setup` wasn't called, the user
    /// isn't identified, or the identity is stale. Transport/server failures throw
    /// — call with `try?` to leave the badge unchanged on error.
    public static func unreadCount() async throws -> Int {
        try await shared?.unreadCount() ?? 0
    }

    /// Send bounded app/device diagnostics (`platform`, `appVersion`, `osVersion`,
    /// `sdkVersion`) for the identified user — nothing else. Explicit and
    /// opt-in: call it after `identify` (e.g. from a "report a problem" action).
    /// No-op if `setup` wasn't called or the user isn't identified. Best-effort;
    /// callers usually ignore errors (`try? await GleanFeed.sendDiagnostics()`).
    public static func sendDiagnostics() async throws {
        try await shared?.sendDiagnostics()
    }

    static func requireClient() throws -> GleanFeedClient {
        guard let shared else { throw GleanFeedError.notConfigured }
        return shared
    }
}
