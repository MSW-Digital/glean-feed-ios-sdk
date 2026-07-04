import XCTest

import GleanFeed

final class GleanFeedTests: XCTestCase {
    /// Smoke test: the module imports as `import GleanFeed` and exposes its
    /// public surface. Behavior is covered by focused tests.
    func testModuleImportsAndExposesVersion() {
        XCTAssertFalse(GleanFeed.version.isEmpty)
    }
}
