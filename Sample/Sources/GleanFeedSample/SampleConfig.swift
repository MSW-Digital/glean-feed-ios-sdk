import GleanFeed

/// Fill these in with **your** workspace values before running.
///
/// `workspaceId` (UUID) and `workspaceSlug` are public — they ship in the web
/// embed snippet — so committing them for your own fork is fine; the sample ships
/// with placeholders. The signed `signature` is generated on **your backend** and
/// pasted into the app at runtime. **No workspace secret ever lives in the app.**
enum SampleConfig {
    static let workspaceId = "REPLACE_WITH_WORKSPACE_UUID"
    static let workspaceSlug = "REPLACE_WITH_WORKSPACE_SLUG"

    /// `.production` → https://gleanfeed.com. For a local dev stack, use
    /// `.custom(baseURL: URL(string: "http://localhost:3000")!)`.
    static let environment: GleanFeedEnvironment = .production
}
