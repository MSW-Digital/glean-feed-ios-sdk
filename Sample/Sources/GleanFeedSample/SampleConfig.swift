import GleanFeed

/// Fill these in with **your** workspace values before running.
///
/// Find both values in Glean Feed under Settings → Connections → iOS SDK. They
/// identify your workspace but are not secrets. The signed `signature` is
/// generated on **your backend** and pasted into the app at runtime. **No
/// workspace secret ever lives in the app.**
enum SampleConfig {
    static let workspaceId = "REPLACE_WITH_WORKSPACE_UUID"
    static let workspaceSlug = "REPLACE_WITH_WORKSPACE_SLUG"

    /// `.production` → https://gleanfeed.com. For a local dev stack, use
    /// `.custom(baseURL: URL(string: "http://localhost:3000")!)`.
    static let environment: GleanFeedEnvironment = .production
}
