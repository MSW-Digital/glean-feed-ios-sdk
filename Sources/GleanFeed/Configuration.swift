import Foundation

/// Which Glean Feed backend the SDK talks to.
public enum GleanFeedEnvironment {
    /// Glean Feed production. `/api/sdk/*` is served from the portal root origin,
    /// matching where the web widget resolves its requests.
    case production

    /// A custom backend origin — local dev, staging, or self-hosted. Pass the
    /// Glean Feed app origin that serves `/api/sdk/*` (scheme + host only, no path).
    /// Use HTTPS outside local dev — tokens ride on this origin (iOS App Transport
    /// Security blocks cleartext by default).
    case custom(baseURL: URL)

    var baseURL: URL {
        switch self {
        case .production:
            // Safe to force-unwrap: a compile-time constant, validated by tests.
            return URL(string: "https://gleanfeed.com")!
        case .custom(let baseURL):
            return baseURL
        }
    }
}

/// A hosted Glean Feed surface the SDK can present.
public enum GleanFeedView: String, CaseIterable, Sendable {
    case feedback
    case roadmap
    case changelog
}

/// Immutable, resolved configuration produced by `GleanFeed.setup`.
struct GleanFeedConfiguration {
    let workspaceId: String
    let workspaceSlug: String
    let baseURL: URL
}
