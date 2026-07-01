import Foundation

/// What the SDK WebView should do with a navigation request.
enum GleanFeedNavigationDecision: Equatable {
    /// Load it in the SDK WebView (same portal origin — incl. the `/auth/sso` hop).
    case allow
    /// Hand off to the system browser — never trap the user inside the SDK.
    case openExternally
}

/// Pure navigation policy. Keeps navigation on the loaded portal origin inside the
/// WebView and sends everything else (third-party links, `mailto:`/`tel:`, external
/// auth) to the system. `portalHost` is the host of the surface URL the WebView was
/// opened with. Platform-agnostic so it's unit-testable without a simulator.
func gleanFeedNavigationDecision(
    for url: URL,
    portalHost: String
) -> GleanFeedNavigationDecision {
    guard let host = url.host, !portalHost.isEmpty else {
        return .openExternally
    }
    return host.caseInsensitiveCompare(portalHost) == .orderedSame ? .allow : .openExternally
}
