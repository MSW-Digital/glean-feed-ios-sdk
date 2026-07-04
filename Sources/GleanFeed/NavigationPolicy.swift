import Foundation

/// What the SDK WebView should do with a navigation request.
enum GleanFeedNavigationDecision: Equatable {
    /// Load it in the SDK WebView (same portal origin — incl. the `/auth/sso` hop).
    case allow
    /// Hand off to the system browser — never trap the user inside the SDK.
    case openExternally
}

/// Pure navigation policy. Keeps navigation on the loaded portal origin inside
/// the WebView and sends everything else (third-party links, `mailto:`/`tel:`,
/// external auth) to the system. `portalOrigin` is the normalized scheme/host/port
/// of the surface URL the WebView was opened with. Platform-agnostic so it's
/// unit-testable without a simulator.
func gleanFeedNavigationDecision(
    for url: URL,
    portalOrigin: String
) -> GleanFeedNavigationDecision {
    guard let origin = gleanFeedOriginKey(url), !portalOrigin.isEmpty else {
        return .openExternally
    }
    return origin.caseInsensitiveCompare(portalOrigin) == .orderedSame ? .allow : .openExternally
}

func gleanFeedOriginKey(_ url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
        return nil
    }
    guard scheme == "http" || scheme == "https" else {
        return nil
    }
    let port = url.port ?? (scheme == "https" ? 443 : 80)
    return "\(scheme)://\(host):\(port)"
}
