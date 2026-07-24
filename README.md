# Glean Feed iOS SDK

> **Beta.** The public API may change before `1.0.0`.

A thin Swift Package that presents hosted [Glean Feed](https://gleanfeed.com)
feedback, roadmap, and changelog surfaces inside your iOS app.

- **iOS 14+**, Swift 5.9+, Swift Package Manager.
- Hosted Glean Feed portal surfaces rendered in a native `WKWebView`.
- Authenticated end users via **server-signed identity** — the workspace secret
  never ships in your app binary.
- Self-service magic-link and Google sign-in via Apple's secure authentication
  session, a PKCE-bound app callback, and an in-WebView one-time handoff.

## Status

**`0.2.1` — native sheet presentation.** The public surface (`setup`, `identify`,
`showFeedback`/`showRoadmap`/`showChangelog` + SwiftUI modifiers, `logout`,
`unreadCount`, `sendDiagnostics`) is shipped. The public API may still change
before `1.0.0` — pin an exact version and review
[GitHub Releases](https://github.com/MSW-Digital/glean-feed-ios-sdk/releases)
before upgrading. Full docs: [gleanfeed.com/docs/ios-sdk](https://gleanfeed.com/docs/ios-sdk/overview).

## Installation

Add the package in Xcode (**File → Add Package Dependencies…**) or in your
`Package.swift`:

```swift
.package(url: "https://github.com/MSW-Digital/glean-feed-ios-sdk", exact: "0.2.1")
```

While the SDK is in beta, pin an exact version so upgrades are deliberate.

Then add `GleanFeed` to your target's dependencies and:

```swift
import GleanFeed
```

## Usage

Configure once at launch:

```swift
import GleanFeed

GleanFeed.setup(
    workspaceId: "workspace-uuid",
    workspaceSlug: "acme",
    callbackURLScheme: "com.example.your-app.gleanfeed"
)

// Optional — `signature` is an HMAC computed on YOUR backend, never in the app.
// Omit to browse anonymously.
try await GleanFeed.identify(
    userId: "user-123",
    email: "person@example.com",
    name: "Person Example",
    signature: signatureFromServer
)
```

Register the same reverse-domain scheme in your target's URL Types. For magic
links, forward incoming URLs to `GleanFeed.handleOpenURL(_:)` from SwiftUI's
`onOpenURL` or your UIKit scene delegate. Google callbacks are handled directly
by `ASWebAuthenticationSession`. The callback contains a short-lived one-time
authorization code bound to the initiating app instance with PKCE; it never
contains a portal session or long-lived user token.

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

Modal surfaces use the native sheet grabber and swipe-down dismissal without
adding a second navigation bar. Push APIs continue to use the host navigation
stack's back button.

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
| `sdkVersion` | `0.2.1` | the SDK |

No logs, screenshots, arbitrary dictionaries, URLs, tokens, emails, names, or
feedback text are ever collected. Diagnostics are **explicit and opt-in**:
**to disable, simply don't call `sendDiagnostics()`.** It is a no-op if the user
isn't identified.

## License

[MIT](LICENSE).
