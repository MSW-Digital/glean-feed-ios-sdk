# Glean Feed iOS SDK

> **Beta.** The public API may change before `1.0.0`.

A thin Swift Package that presents hosted [Glean Feed](https://gleanfeed.com)
feedback, roadmap, and changelog surfaces inside your iOS app — no native
re-implementation, no sending users to Safari.

- **iOS 14+**, Swift 5.9+, Swift Package Manager.
- Hosted Glean Feed portal surfaces rendered in a native `WKWebView`.
- Authenticated end users via **server-signed identity** — the workspace secret
  never ships in your app binary.

## Sample app

A runnable sample lives in [`Sample/`](Sample) — open that folder in Xcode (it's
a standalone App package) and run. It exercises setup, identify/logout, the three
surfaces, diagnostics, and the unread count. Fill in your workspace values in
`Sample/Sources/GleanFeedSample/SampleConfig.swift`; no secret goes in the app.
See [`docs/simulator-qa.md`](docs/simulator-qa.md) for the QA checklist.

## Status

This is the package skeleton (GF-212). The public API —
`setup`, `identify`, `showFeedback`, `showRoadmap`, `showChangelog`, `logout` —
lands in the following PRs. Track progress in the
[Glean Feed — iOS SDK](https://linear.app/mswdigital/project/glean-feed-ios-sdk-86ad78558cb3)
project.

## Installation

> Version-pinned installation resolves once the first beta is tagged (GF-219).
> Until then, depend on the `main` branch.

Add the package in Xcode (**File → Add Package Dependencies…**) or in your
`Package.swift`:

```swift
// After the first beta tag:
.package(url: "https://github.com/MSW-Digital/glean-feed-ios-sdk", from: "0.1.0")
// Before then:
.package(url: "https://github.com/MSW-Digital/glean-feed-ios-sdk", branch: "main")
```

Then add `GleanFeed` to your target's dependencies and:

```swift
import GleanFeed
```

## Usage

Configure once at launch:

```swift
import GleanFeed

GleanFeed.setup(workspaceId: "workspace-uuid", workspaceSlug: "acme")

// Optional — `signature` is an HMAC computed on YOUR backend, never in the app.
// Omit to browse anonymously.
try await GleanFeed.identify(
    userId: "user-123",
    email: "person@example.com",
    name: "Person Example",
    signature: signatureFromServer
)
```

Present a surface as a sheet — **UIKit** (omit `from:` to use the top-most controller):

```swift
GleanFeed.showFeedback()
GleanFeed.showRoadmap(from: self)
GleanFeed.showChangelog()

// …or push onto your own navigation stack:
GleanFeed.pushFeedback(onto: navigationController)
```

…or **SwiftUI**, bound to state:

```swift
.gleanFeedFeedback(isPresented: $showingFeedback)
.gleanFeedRoadmap(isPresented: $showingRoadmap)
.gleanFeedChangelog(isPresented: $showingChangelog)
```

Sign the user out of Glean Feed (does not touch your app's own auth):

```swift
GleanFeed.logout()
```

## Unread count (badge)

Show a native "What's new" badge for signed-in users. Returns `0` for anonymous
or stale identities; call with `try?` to leave the badge as-is on a transient
error:

```swift
// e.g. on foreground, or in a settings row
let count = (try? await GleanFeed.unreadCount()) ?? 0
settingsRow.badge = count > 0 ? "\(count)" : nil
```

There's no push, background polling, or app-icon badging in v1 — poll
`unreadCount()` from your own foreground refresh when you want a fresh value.

## Diagnostics (optional)

To attach bounded app/device context to an identified user, call:

```swift
try? await GleanFeed.sendDiagnostics()   // call after identify(), e.g. from a "report a problem" action
```

It sends **only** these four fields — nothing else:

| Field | Example | Source |
| --- | --- | --- |
| `platform` | `ios` | constant |
| `appVersion` | `1.2.3` | `CFBundleShortVersionString` (omitted if unset) |
| `osVersion` | `18.1.0` | `ProcessInfo.operatingSystemVersion` |
| `sdkVersion` | `0.0.0` | the SDK |

No logs, screenshots, arbitrary dictionaries, URLs, tokens, emails, names, or
feedback text are ever collected. Diagnostics are **explicit and opt-in**:
**to disable, simply don't call `sendDiagnostics()`.** It is a no-op if the user
isn't identified.

## License

[MIT](LICENSE).
