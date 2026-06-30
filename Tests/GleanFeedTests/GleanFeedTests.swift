import XCTest

import GleanFeed

final class GleanFeedTests: XCTestCase {
    /// Smoke test: the module imports as `import GleanFeed` and exposes its
    /// public surface. Real behavior is covered once GF-213/GF-214 land.
    func testModuleImportsAndExposesVersion() {
        XCTAssertFalse(GleanFeed.version.isEmpty)
    }
}
