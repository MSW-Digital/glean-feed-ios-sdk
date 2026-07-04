# Release checklist — iOS SDK

Run before creating each release tag. Tag only after every box is checked.

## Build & test

- [ ] `swift test` passes (macOS host).
- [ ] `xcodebuild build -scheme GleanFeed -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` builds.
- [ ] A fresh, separate Xcode project can **Add Package Dependencies…** from the public URL, `import GleanFeed`, call `GleanFeed.setup(...)`, and build for the iOS simulator.
- [ ] Smoke the current backend contract from a local app stack: anonymous `portal-url`, signed `identify`, and SSO handoff.

## Version & docs

- [ ] `GleanFeed.version` matches the tag.
- [ ] `CHANGELOG.md` has an entry for this version with beta caveats and known limits.
- [ ] README install snippet points to the tagged version.
- [ ] Public docs ([gleanfeed.com/docs/ios-sdk](https://gleanfeed.com/docs/ios-sdk/overview)) and the dashboard setup page (**Settings → Connections → iOS SDK**) reference the released version and the correct package URL.

## Privacy & security posture

- [ ] No secrets in the repo — `grep -ri "secret\|hmac\|cryptokit"` over `Sources/`, `Tests/`, `docs/`, and `.github/` finds only doc text.
- [ ] No token logging — no `print`/`NSLog`/`os_log` in `Sources/`; tokens never appear in error descriptions.
- [ ] Diagnostics bounded to `platform`/`appVersion`/`osVersion`/`sdkVersion`, opt-in only.
- [ ] WebView keeps portal navigation in-container for the exact resolved portal origin; external and non-`http(s)`/`mailto`/`tel` schemes are handed off or cancelled, never loaded in the SDK WebView.

## Tag

- [ ] Create the GitHub release/tag `vX.Y.Z` with the changelog notes and clear beta caveats + known limits.
