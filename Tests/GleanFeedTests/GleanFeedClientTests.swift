import XCTest

@testable import GleanFeed

final class GleanFeedClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Self-defending: don't inherit global state from a prior case.
        MockURLProtocol.reset()
        GleanFeed.shared = nil
    }

    override func tearDown() {
        MockURLProtocol.reset()
        GleanFeed.shared = nil
        super.tearDown()
    }

    // MARK: identify

    func testIdentifySuccessStoresTokens() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let store = InMemoryTokenStore()
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)

        try await client.identify(userId: "u1", email: "a@b.com", name: "A B", signature: "sig")

        XCTAssertEqual(store.userToken(), "user-token-123")
        XCTAssertTrue(client.isIdentified)
    }

    func testIdentifyInvalidResponseThrows() async {
        // 200 but missing the required `userToken` field → decode failure.
        MockURLProtocol.handler = { _ in (200, Fixtures.json(#"{"ssoToken":"x"}"#)) }
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())

        await assertThrows(.invalidResponse) {
            try await client.identify(userId: "u1", email: nil, name: nil, signature: "sig")
        }
    }

    func testIdentifyFailsClosedWhenPersistenceFails() async {
        // A Keychain write failure must fail identify, not leave it half-applied
        // (identified in memory but with no persisted token).
        MockURLProtocol.handler = Fixtures.routeOK
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: FailingTokenStore())

        await assertThrows(.storage) {
            try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")
        }
        XCTAssertFalse(client.isIdentified)
    }

    /// `URLProtocol` can't see the streamed `httpBody`, so assert the wire contract
    /// at the encoder — the exact code path `APIClient.identify` runs.
    func testIdentifyRequestEncodesExpectedFields() throws {
        let withProfile = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(
                IdentifyRequest(workspaceId: "w1", userId: "u1", email: "a@b.com", name: "A B", signature: "sig")
            )
        ) as? [String: Any]
        XCTAssertEqual(withProfile?["workspaceId"] as? String, "w1")
        XCTAssertEqual(withProfile?["userId"] as? String, "u1")
        XCTAssertEqual(withProfile?["email"] as? String, "a@b.com")
        XCTAssertEqual(withProfile?["name"] as? String, "A B")
        XCTAssertEqual(withProfile?["signature"] as? String, "sig")

        // nil email/name are omitted (not encoded as null) — the legacy
        // `workspaceId:userId` signature path depends on this.
        let anonymous = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(
                IdentifyRequest(workspaceId: "w1", userId: "u1", email: nil, name: nil, signature: "sig")
            )
        ) as? [String: Any]
        XCTAssertEqual(anonymous?.keys.sorted(), ["signature", "userId", "workspaceId"])
    }

    func testIdentifyRejectedOnUnauthorized() async {
        MockURLProtocol.handler = { _ in (401, Fixtures.json(#"{"error":"Invalid signature."}"#)) }
        let store = InMemoryTokenStore()
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)

        await assertThrows(.identityRejected) {
            try await client.identify(userId: "u1", email: nil, name: nil, signature: "bad")
        }
        XCTAssertNil(store.userToken(), "a rejected identify must not persist a token")
        XCTAssertFalse(client.isIdentified)
    }

    // MARK: logout

    func testLogoutClearsTokensAndIdentity() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let store = InMemoryTokenStore()
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")

        client.logout()

        XCTAssertNil(store.userToken())
        XCTAssertFalse(client.isIdentified)
    }

    // MARK: surface URL resolution

    func testSurfaceURLAuthenticatedUsesSSOHandoff() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")

        let url = try await client.surfaceURL(for: .roadmap)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.host, "acme.gleanfeed.com")
        XCTAssertEqual(components?.path, "/portal/acme/auth/sso")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "token" })?.value, "sso-token-abc")
        XCTAssertEqual(
            components?.queryItems?.first(where: { $0.name == "returnTo" })?.value,
            "/portal/acme/roadmap"
        )
    }

    func testSurfaceURLConsumesSSOTokenAfterFirstUse() async throws {
        // First open uses the SSO handoff; the single-use token is consumed, so the
        // second open uses the direct surface URL (rides the session cookie).
        MockURLProtocol.handler = Fixtures.routeOK
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")

        let first = try await client.surfaceURL(for: .feedback)
        XCTAssertEqual(URLComponents(url: first, resolvingAgainstBaseURL: false)?.path, "/portal/acme/auth/sso")

        let second = try await client.surfaceURL(for: .feedback)
        XCTAssertEqual(second.absoluteString, "https://acme.gleanfeed.com/portal/acme/feedback")
    }

    func testSurfaceURLAnonymousWhenNotIdentified() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())

        let url = try await client.surfaceURL(for: .feedback)

        XCTAssertEqual(url.absoluteString, "https://acme.gleanfeed.com/portal/acme/feedback")
    }

    func testSurfaceURLFallsBackToAnonymousAfterLogout() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")
        client.logout()

        let url = try await client.surfaceURL(for: .changelog)

        XCTAssertEqual(url.absoluteString, "https://acme.gleanfeed.com/portal/acme/changelog")
    }

    // MARK: facade

    func testFacadeThrowsWhenNotConfigured() async {
        GleanFeed.shared = nil
        await assertThrows(.notConfigured) {
            try await GleanFeed.identify(userId: "u1", signature: "sig")
        }
    }

    func testFacadeSetupAndIdentify() async throws {
        MockURLProtocol.handler = Fixtures.routeOK
        let store = InMemoryTokenStore()
        // Inject a mock-backed client into the facade.
        GleanFeed.shared = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)

        try await GleanFeed.identify(userId: "u1", email: "a@b.com", signature: "sig")
        XCTAssertEqual(store.userToken(), "user-token-123")

        GleanFeed.logout()
        XCTAssertNil(store.userToken())
    }

    // MARK: helper

    private func assertThrows(
        _ expected: GleanFeedError,
        _ body: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected) to be thrown", file: file, line: line)
        } catch let error as GleanFeedError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected \(expected), got \(error)", file: file, line: line)
        }
    }
}
