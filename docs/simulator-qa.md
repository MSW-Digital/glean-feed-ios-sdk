# Simulator QA harness

`swift test` covers the pure logic (URL resolution, navigation policy, token/
diagnostics/notification behavior). Actual `WKWebView` presentation and the
end-to-end flows are verified by hand in the simulator using the **sample app**
until automated UI testing lands.

## Running the sample

The sample is a normal iOS app project at [`../Sample`](../Sample).

1. Open **`Sample/GleanFeedSample.xcodeproj`** in Xcode. (The project is generated
   from `Sample/project.yml` via XcodeGen; regenerate with `cd Sample && xcodegen generate`
   only if you change that spec — the `.xcodeproj` is committed, so you don't need
   XcodeGen just to run it.)
2. Edit `Sample/Sources/GleanFeedSample/SampleConfig.swift` — set your
   `workspaceId` and `workspaceSlug` (both are public), and `.production` or a
   `.custom(baseURL:)` local dev origin. **No workspace secret goes in the app.**
3. Generate a signed `signature` on your backend (HMAC over the workspace secret)
   and paste it into the app's Signature field to test signed mode.
4. Pick a simulator and hit Run (⌘R).

## Checklist

Run the full list on **two simulators**: the **iOS 14 baseline** and the
**latest iOS**.

**Setup / anonymous**
- [ ] App launches; `GleanFeed.setup(...)` ran (no crash, "Anonymous" status).
- [ ] `Show Feedback` / `Roadmap` / `Changelog` each present a full-height sheet with a native **Done** button, loading spinner, then the public (signed-out) surface.
- [ ] **Done** dismisses.

**Signed**
- [ ] Paste userId + a valid backend signature → **Identify** → status shows signed-in.
- [ ] `Show Feedback` now lands **signed-in** (SSO handoff → surface).
- [ ] Dismiss and reopen — still signed-in (SSO token consumed once; rides the session cookie).

**Logout**
- [ ] **Logout** → status "Anonymous", unread resets to 0.
- [ ] (Known v1 limitation) a surface opened right after logout may still show signed-in until the portal session expires — the WebView cookie isn't cleared yet.

**Navigation containment**
- [ ] An in-portal link stays inside the WebView.
- [ ] An external link (third-party URL, "Powered by") opens in the **system browser**, not the SDK WebView.
- [ ] `mailto:`/`tel:` leave the WebView; an app-scheme deep link does **not** silently launch another app.

**Failed network**
- [ ] Turn the network off (simulator or device). Present a surface → the failure label shows; tap it to retry.
- [ ] `Refresh unread` with the network off leaves the badge unchanged (no error UI).
- [ ] `Send diagnostics` with the network off shows "failed" (no crash).

**Diagnostics**
- [ ] After identify, `Send diagnostics` → "sent". Confirm the `sdk_diagnostics_received` event server-side carries only `platform`/`appVersion`/`osVersion`/`sdkVersion`.
- [ ] `Send diagnostics` while anonymous is a no-op (no request).

**Unread count**
- [ ] Signed-in: `Refresh unread` shows the server count.
- [ ] Anonymous: unread is 0.

**UIKit presenters** (not wired in the SwiftUI sample; share the same WebView controller)
- [ ] If exercising from a UIKit host: `GleanFeed.showFeedback(from:)` presents; `pushFeedback(onto:)` pushes with a back button (no Done).
