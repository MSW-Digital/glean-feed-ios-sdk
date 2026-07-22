import XCTest

@testable import GleanFeed

final class NavigationPolicyTests: XCTestCase {
    private func decide(_ urlString: String, portalOrigin: String) -> GleanFeedNavigationDecision {
        gleanFeedNavigationDecision(for: URL(string: urlString)!, portalOrigin: portalOrigin)
    }

    func testSameHostStaysInWebView() {
    XCTAssertEqual(
      decide(
        "https://acme.gleanfeed.com/portal/acme/feedback",
        portalOrigin: "https://acme.gleanfeed.com:443"), .allow)
    }

    func testSSOHandoffSameHostStaysInWebView() {
        XCTAssertEqual(
      decide(
        "https://acme.gleanfeed.com/portal/acme/auth/sso?token=x&returnTo=/portal/acme/feedback",
                   portalOrigin: "https://acme.gleanfeed.com:443"),
            .allow
        )
    }

    func testCustomDomainSameHostStaysInWebView() {
    XCTAssertEqual(
      decide(
        "https://feedback.acme.com/portal/acme/roadmap",
        portalOrigin: "https://feedback.acme.com:443"), .allow)
    }

    func testHostMatchIsCaseInsensitive() {
    XCTAssertEqual(
      decide(
        "https://ACME.GleanFeed.com/portal/acme/changelog",
        portalOrigin: "https://acme.gleanfeed.com:443"), .allow)
    }

    func testDifferentHostOpensExternally() {
    XCTAssertEqual(
      decide("https://twitter.com/acme", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    XCTAssertEqual(
      decide("https://gleanfeed.com/pricing", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    }

    func testSchemeWithoutHostOpensExternally() {
    XCTAssertEqual(
      decide("mailto:hello@acme.com", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    XCTAssertEqual(
      decide("tel:+15551234567", portalOrigin: "https://acme.gleanfeed.com:443"), .openExternally)
    }

    func testEmptyPortalOriginOpensExternally() {
        // No resolved portal origin yet → never trap navigation in the WebView.
    XCTAssertEqual(
      decide("https://acme.gleanfeed.com/portal/acme/feedback", portalOrigin: ""), .openExternally)
    }

    func testSubdomainOfPortalHostOpensExternally() {
        // Exact host match only — a subdomain is a different origin. Locks this in
        // so a future `hasSuffix`-style change can't silently open a hole.
    XCTAssertEqual(
      decide("https://evil.acme.gleanfeed.com/x", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    }

    func testOpaqueSchemesOpenExternally() {
        // javascript:/data: have no host → external (and the delegate's scheme
        // allowlist then declines to hand these to the system).
    XCTAssertEqual(
      decide("javascript:doThing", portalOrigin: "https://acme.gleanfeed.com:443"), .openExternally)
    XCTAssertEqual(
      decide("data:text/plain;base64,aGk=", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    }

    func testSameHostWithDifferentPortOpensExternally() {
    XCTAssertEqual(
      decide("https://acme.gleanfeed.com:8443/x", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    }

    func testSameHostWithDifferentSchemeOpensExternally() {
    XCTAssertEqual(
      decide("http://acme.gleanfeed.com/x", portalOrigin: "https://acme.gleanfeed.com:443"),
      .openExternally)
    }

    func testOriginKeyNormalizesDefaultPorts() {
    XCTAssertEqual(
      gleanFeedOriginKey(URL(string: "https://acme.gleanfeed.com/x")!),
      "https://acme.gleanfeed.com:443")
    XCTAssertEqual(
      gleanFeedOriginKey(URL(string: "http://localhost:3000/x")!), "http://localhost:3000")
  }

  func testNativeAuthHandoffMustReturnToTheLoadedPortalOrigin() {
    XCTAssertTrue(
      isTrustedNativeAuthHandoff(
        URL(string: "https://acme.gleanfeed.com/auth/oauth-finish?token=one-time")!,
        portalOrigin: "https://acme.gleanfeed.com:443"
      )
    )
    XCTAssertFalse(
      isTrustedNativeAuthHandoff(
        URL(string: "https://evil.example/auth/oauth-finish?token=stolen")!,
        portalOrigin: "https://acme.gleanfeed.com:443"
      )
    )
    XCTAssertFalse(
      isTrustedNativeAuthHandoff(
        URL(string: "https://acme.gleanfeed.com/feedback")!,
        portalOrigin: "https://acme.gleanfeed.com:443"
      )
    )
    }
}
