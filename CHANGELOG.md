# Changelog

All notable changes to the Glean Feed iOS SDK. The format follows
[Keep a Changelog](https://keepachangelog.com); the project uses
[Semantic Versioning](https://semver.org). **Pre-1.0:** minor versions may
include breaking changes while the API stabilizes — pin an exact version.

## 0.1.0 — 2026-07-01

First public beta.

### Added

- `GleanFeed.setup(workspaceId:workspaceSlug:environment:)` — configure once at
  launch. `environment` defaults to `.production`; use `.custom(baseURL:)` for a
  dev/self-hosted stack.
- `GleanFeed.identify(userId:email:name:signature:)` and `logout()` — server-signed
  identity. The long-lived user token is stored in the Keychain; the short-lived
  SSO token is memory-only. The SDK never computes signatures or holds a secret.
- Presentation of hosted portal surfaces in a `WKWebView`:
  - UIKit: `showFeedback()` / `showRoadmap()` / `showChangelog()` (+ `from:`),
    and `pushFeedback(onto:)` / `pushRoadmap(onto:)` / `pushChangelog(onto:)`.
  - SwiftUI: `.gleanFeedFeedback(isPresented:)` / `.gleanFeedRoadmap(isPresented:)`
    / `.gleanFeedChangelog(isPresented:)`.
- `GleanFeed.unreadCount()` — unread count for a native badge (signed-in users only).
- `GleanFeed.sendDiagnostics()` — explicit, opt-in, bounded to `platform`,
  `appVersion`, `osVersion`, `sdkVersion`. Nothing else is collected.

### Security & privacy

- No widget secret or signing helper in the package; signatures are generated on
  the customer's backend only.
- No token logging; tokens never appear in error descriptions.
- Portal navigation stays inside the WebView for the workspace origin; external
  links (and non-`http(s)`/`mailto`/`tel` schemes) are handed to the system or
  cancelled — the user is never trapped on a foreign host.

### Known limitations (beta)

- The public API may change before `1.0.0`.
- iOS 14+ only. No macOS, Android, React Native, or Flutter.
- No push notifications, background polling, app-icon badges, screenshots, file
  attachments, or offline queueing.
- `logout()` clears SDK tokens and in-memory identity but not the WebView's portal
  session cookie — a surface opened right after logout may appear signed-in until
  the portal session expires. Hardening tracked for a follow-up.
