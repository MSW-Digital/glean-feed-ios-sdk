import XCTest

import GleanFeed

final class GleanFeedTests: XCTestCase {
    /// Smoke test: the module imports as `import GleanFeed` and exposes its
    /// public surface. Behavior is covered by focused tests.
    func testModuleImportsAndExposesVersion() {
        XCTAssertEqual(GleanFeed.version, "0.2.1")
    }
}
