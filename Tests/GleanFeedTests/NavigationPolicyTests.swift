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
}
