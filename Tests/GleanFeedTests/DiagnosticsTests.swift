import XCTest

@testable import GleanFeed

final class DiagnosticsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

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

    // MARK: request encoding (URLProtocol can't see the streamed httpBody)

    func testDiagnosticsRequestEncodesExpectedFields() throws {
        let body = DiagnosticsRequest(
            workspaceId: "w1",
            userToken: "utoken",
            metadata: ["platform": "ios", "sdkVersion": "0.0.0"]
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
        XCTAssertEqual(json?["workspaceId"] as? String, "w1")
        XCTAssertEqual(json?["userToken"] as? String, "utoken")
        XCTAssertEqual(json?["metadata"] as? [String: String], ["platform": "ios", "sdkVersion": "0.0.0"])
    }

    // MARK: client send / skip

    func testSendDiagnosticsPostsToDiagnosticsWhenIdentified() async throws {
        let paths = PathRecorder()
        MockURLProtocol.handler = { request in
            paths.record(request.url?.path ?? "")
            return try Fixtures.routeOK(request)
        }
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")

        try await client.sendDiagnostics()

        XCTAssertTrue(
            paths.paths.contains { $0.hasSuffix("/api/sdk/diagnostics") },
            "an identified sendDiagnostics must POST /api/sdk/diagnostics"
        )
    }

    func testSendDiagnosticsSkipsWhenNotIdentified() async throws {
        MockURLProtocol.handler = { _ in
            XCTFail("diagnostics must not hit the network without an identity")
            return (200, Data())
        }
        // No identify → no stored userToken.
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())

        try await client.sendDiagnostics() // returns without a request
    }
}

/// Ordered record of request paths seen by the mock. Writes happen on the
/// URLProtocol thread but are read after the `await` completes (happens-before),
/// so a plain lock-guarded array is sufficient.
final class PathRecorder {
    private let lock = NSLock()
    private var storage: [String] = []
    func record(_ path: String) { lock.lock(); storage.append(path); lock.unlock() }
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return storage }
}
