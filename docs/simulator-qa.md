# Simulator QA — presentation (GF-214)

`swift test` covers the URL-resolution and navigation-policy logic. Actual
`WKWebView` behavior is verified by hand in the simulator until the sample app
lands (GF-217). Run through this after changing the presentation layer.

Setup once in the host/sample app:

```swift
GleanFeed.setup(workspaceId: "<uuid>", workspaceSlug: "<slug>")
```

## Checklist

**Anonymous**
- [ ] `GleanFeed.showFeedback()` presents a full-height sheet with a native **Done** button.
- [ ] The feedback surface loads (public portal, signed-out).
- [ ] `showRoadmap()` and `showChangelog()` each open the right surface.
- [ ] **Done** dismisses the sheet.

**Authenticated**
- [ ] After `try await GleanFeed.identify(userId:email:signature:)`, `showFeedback()` lands signed-in (SSO handoff → surface).
- [ ] `GleanFeed.logout()` then `showFeedback()` opens signed-out again.

**Navigation containment**
- [ ] Tapping an in-portal link stays inside the WebView.
- [ ] Tapping an external link (e.g. a "Powered by" link, a third-party URL) opens in the **system browser**, not the SDK WebView.
- [ ] `mailto:` / `tel:` links leave the WebView.

**States**
- [ ] Loading shows the spinner; it stops on load.
- [ ] With the network off, the failure label shows; tapping it retries.

**SwiftUI**
- [ ] `.gleanFeedFeedback(isPresented:)` presents/dismisses correctly bound to state.
- [ ] `.gleanFeedRoadmap` / `.gleanFeedChangelog` likewise.

**UIKit presenter**
- [ ] `GleanFeed.showFeedback(from: someVC)` presents from the given controller.
- [ ] `GleanFeed.showFeedback()` (no presenter) finds the top-most controller and presents.
