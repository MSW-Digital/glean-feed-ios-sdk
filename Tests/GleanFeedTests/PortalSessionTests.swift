import XCTest

@testable import GleanFeed

final class PortalSessionTests: XCTestCase {
    func testCookieDomainMatchingClearsGleanFeedSessionWithoutBroadCustomDomainDelete() {
        let gleanFeedHosts = ["acme.gleanfeed.com", "gleanfeed.com"]
        XCTAssertTrue(gleanFeedShouldClearCookieDomain("acme.gleanfeed.com", portalHosts: Set(gleanFeedHosts)))
        XCTAssertTrue(gleanFeedShouldClearCookieDomain(".gleanfeed.com", portalHosts: Set(gleanFeedHosts)))

        let customHosts: Set<String> = ["feedback.acme.com"]
        XCTAssertTrue(gleanFeedShouldClearCookieDomain("feedback.acme.com", portalHosts: customHosts))
        XCTAssertFalse(gleanFeedShouldClearCookieDomain(".acme.com", portalHosts: customHosts))
    }
}
