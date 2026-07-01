import XCTest

@testable import GleanFeed

final class DiagnosticsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: metadata whitelist

    func testPayloadContainsOnlyWhitelistedFields() {
        let metadata = DiagnosticsMetadata(appVersion: "1.2.3", osVersion: "18.1.0", sdkVersion: "0.0.0")
        XCTAssertEqual(
            metadata.payload,
            [
                "platform": "ios",
                "appVersion": "1.2.3",
                "osVersion": "18.1.0",
                "sdkVersion": "0.0.0",
            ]
        )
    }

    func testPayloadOmitsMissingAppVersion() {
        let metadata = DiagnosticsMetadata(appVersion: nil, osVersion: "18.1.0", sdkVersion: "0.0.0")
        XCTAssertEqual(metadata.payload, ["platform": "ios", "osVersion": "18.1.0", "sdkVersion": "0.0.0"])
        XCTAssertNil(metadata.payload["appVersion"])

        let empty = DiagnosticsMetadata(appVersion: "", osVersion: "18.1.0", sdkVersion: "0.0.0")
        XCTAssertNil(empty.payload["appVersion"], "empty appVersion is omitted, not sent as \"\"")
    }

    func testCurrentDerivesOSVersionFromProcessInfo() {
        let metadata = DiagnosticsMetadata.current(sdkVersion: "9.9.9")
        let os = ProcessInfo.processInfo.operatingSystemVersion
        XCTAssertEqual(metadata.osVersion, "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        XCTAssertEqual(metadata.sdkVersion, "9.9.9")
        XCTAssertEqual(metadata.platform, "ios")
    }

    // MARK: client send / skip

    func testSendDiagnosticsSucceedsWhenIdentified() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let store = InMemoryTokenStore()
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")

        try await client.sendDiagnostics() // does not throw
    }

    func testSendDiagnosticsSkipsWhenNotIdentified() async throws {
        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            return try Fixtures.routeOK(request)
        }
        // No identify → no stored userToken.
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())

        try await client.sendDiagnostics()

        XCTAssertEqual(requestCount, 0, "diagnostics must not hit the network without an identity")
    }
}
