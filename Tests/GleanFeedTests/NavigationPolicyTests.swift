import XCTest

@testable import GleanFeed

final class NavigationPolicyTests: XCTestCase {
    private func decide(_ urlString: String, portalHost: String) -> GleanFeedNavigationDecision {
        gleanFeedNavigationDecision(for: URL(string: urlString)!, portalHost: portalHost)
    }

    func testSameHostStaysInWebView() {
        XCTAssertEqual(decide("https://acme.gleanfeed.com/portal/acme/feedback", portalHost: "acme.gleanfeed.com"), .allow)
    }

    func testSSOHandoffSameHostStaysInWebView() {
        XCTAssertEqual(
            decide("https://acme.gleanfeed.com/portal/acme/auth/sso?token=x&returnTo=/portal/acme/feedback",
                   portalHost: "acme.gleanfeed.com"),
            .allow
        )
    }

    func testCustomDomainSameHostStaysInWebView() {
        XCTAssertEqual(decide("https://feedback.acme.com/portal/acme/roadmap", portalHost: "feedback.acme.com"), .allow)
    }

    func testHostMatchIsCaseInsensitive() {
        XCTAssertEqual(decide("https://ACME.GleanFeed.com/portal/acme/changelog", portalHost: "acme.gleanfeed.com"), .allow)
    }

    func testDifferentHostOpensExternally() {
        XCTAssertEqual(decide("https://twitter.com/acme", portalHost: "acme.gleanfeed.com"), .openExternally)
        XCTAssertEqual(decide("https://gleanfeed.com/pricing", portalHost: "acme.gleanfeed.com"), .openExternally)
    }

    func testSchemeWithoutHostOpensExternally() {
        XCTAssertEqual(decide("mailto:hello@acme.com", portalHost: "acme.gleanfeed.com"), .openExternally)
        XCTAssertEqual(decide("tel:+15551234567", portalHost: "acme.gleanfeed.com"), .openExternally)
    }

    func testEmptyPortalHostOpensExternally() {
        // No resolved portal origin yet → never trap navigation in the WebView.
        XCTAssertEqual(decide("https://acme.gleanfeed.com/portal/acme/feedback", portalHost: ""), .openExternally)
    }

    func testSubdomainOfPortalHostOpensExternally() {
        // Exact host match only — a subdomain is a different origin. Locks this in
        // so a future `hasSuffix`-style change can't silently open a hole.
        XCTAssertEqual(decide("https://evil.acme.gleanfeed.com/x", portalHost: "acme.gleanfeed.com"), .openExternally)
    }

    func testOpaqueSchemesOpenExternally() {
        // javascript:/data: have no host → external (and the delegate's scheme
        // allowlist then declines to hand these to the system).
        XCTAssertEqual(decide("javascript:doThing", portalHost: "acme.gleanfeed.com"), .openExternally)
        XCTAssertEqual(decide("data:text/plain;base64,aGk=", portalHost: "acme.gleanfeed.com"), .openExternally)
    }

    func testHostWithPortDoesNotMatchBareHost() {
        // Documents current behavior: URL.host strips the port, so this matches.
        XCTAssertEqual(decide("https://acme.gleanfeed.com:8443/x", portalHost: "acme.gleanfeed.com"), .allow)
    }
}
