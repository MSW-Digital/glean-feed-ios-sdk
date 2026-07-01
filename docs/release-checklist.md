# Release checklist — iOS SDK

Run before creating each release tag. Tag only after every box is checked.

## Build & test

- [ ] `swift test` passes (macOS host).
- [ ] `xcodebuild build -scheme GleanFeed -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` builds.
- [ ] The sample builds and runs from `Sample/GleanFeedSample.xcodeproj` — on an iOS 14 baseline simulator and on the latest simulator.
- [ ] A fresh, separate Xcode project can **Add Package Dependencies…** from the public URL and `import GleanFeed`.

## Simulator QA — see [`simulator-qa.md`](simulator-qa.md)

- [ ] Anonymous: feedback / roadmap / changelog open and render the compact embed shell (not the full site), with the tab bar pinned.
- [ ] Signed: `identify` with a backend signature opens authenticated surfaces; `logout` returns to anonymous.
- [ ] External links leave the WebView; the **Done** button dismisses; the failure/retry state appears with no network.
- [ ] `unreadCount()` reflects signed-in state; `sendDiagnostics()` sends only the four whitelisted fields.

## Version & docs

- [ ] `GleanFeed.version` matches the tag.
- [ ] `CHANGELOG.md` has an entry for this version with beta caveats and known limits.
- [ ] README install snippet points to the tagged version.
- [ ] Public docs ([gleanfeed.com/docs/ios-sdk](https://gleanfeed.com/docs/ios-sdk/overview)) and the dashboard setup page (**Settings → Connections → iOS SDK**) reference the released version and the correct package URL.

## Privacy & security posture

- [ ] No secrets in the repo or sample — `grep -ri "secret\|hmac\|cryptokit"` over `Sources/` and `Sample/` finds only doc text.
- [ ] No token logging — no `print`/`NSLog`/`os_log` in `Sources/`; tokens never appear in error descriptions.
- [ ] Diagnostics bounded to `platform`/`appVersion`/`osVersion`/`sdkVersion`, opt-in only.
- [ ] WebView keeps portal navigation in-container for the workspace origin; external and non-`http(s)`/`mailto`/`tel` schemes are handed off or cancelled, never loaded in the SDK WebView.

## Tag

- [ ] Create the GitHub release/tag `vX.Y.Z` with the changelog notes and clear beta caveats + known limits.
