# Glean Feed iOS SDK

> **Beta.** The public API may change before `1.0.0`.

A thin Swift Package that presents hosted [Glean Feed](https://gleanfeed.com)
feedback, roadmap, and changelog surfaces inside your iOS app — no native
re-implementation, no sending users to Safari.

- **iOS 14+**, Swift 5.9+, Swift Package Manager.
- Hosted Glean Feed portal surfaces rendered in a native `WKWebView`.
- Authenticated end users via **server-signed identity** — the workspace secret
  never ships in your app binary.

## Status

This is the package skeleton (GF-212). The public API —
`setup`, `identify`, `showFeedback`, `showRoadmap`, `showChangelog`, `logout` —
lands in the following PRs. Track progress in the
[Glean Feed — iOS SDK](https://linear.app/mswdigital/project/glean-feed-ios-sdk-86ad78558cb3)
project.

## Installation

Add the package in Xcode (**File → Add Package Dependencies…**) or in your
`Package.swift`:

```swift
.package(url: "https://github.com/MSW-Digital/glean-feed-ios-sdk", from: "0.0.0")
```

Then add `GleanFeed` to your target's dependencies and:

```swift
import GleanFeed
```

## Usage

The presentation API arrives in a later beta release. Planned shape:

```swift
import GleanFeed

GleanFeed.setup(workspaceId: "workspace-uuid", workspaceSlug: "acme")

// Optional — `signature` is an HMAC computed on YOUR backend, never in the app.
GleanFeed.identify(
    userId: "user-123",
    email: "person@example.com",
    name: "Person Example",
    signature: signatureFromServer
)

GleanFeed.showFeedback()
GleanFeed.showRoadmap()
GleanFeed.showChangelog()
```

## License

[MIT](LICENSE).
