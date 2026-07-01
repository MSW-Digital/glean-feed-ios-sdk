import GleanFeed

/// Fill these in with **your** workspace values before running.
///
/// `workspaceSlug` is public (it's in the portal URL and the web embed snippet).
/// `workspaceId` (UUID) is required by `identify` but is **not surfaced to
/// customers yet** — get it from workspace admin settings (coming with the
/// dashboard install surface). It isn't a secret, but don't publish it, so this
/// committed file keeps a placeholder. The signed `signature` is generated on
/// **your backend** and pasted into the app at runtime. **No workspace secret
/// ever lives in the app.**
enum SampleConfig {
    static let workspaceId = "REPLACE_WITH_WORKSPACE_UUID"
    static let workspaceSlug = "feedback"

    /// `.production` → https://gleanfeed.com. For a local dev stack, use
    /// `.custom(baseURL: URL(string: "http://localhost:3000")!)`.
    static let environment: GleanFeedEnvironment = .production
}
