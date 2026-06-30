import Foundation

/// Glean Feed iOS SDK — **beta**.
///
/// Presents hosted Glean Feed feedback, roadmap, and changelog surfaces inside a
/// native `WKWebView`, backed by server-signed end-user identity. This is the
/// package skeleton (GF-212); the public API —
/// `setup`, `identify`, `showFeedback`, `showRoadmap`, `showChangelog`, `logout`
/// — lands in GF-213/GF-214.
///
/// See the contract in the Glean Feed repo: `docs/ios-sdk/README.md`.
public enum GleanFeed {
    /// The SDK version. Beta: the public API may change before `1.0.0`.
    public static let version = "0.0.0"
}
