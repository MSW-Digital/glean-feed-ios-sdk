import XCTest

@testable import GleanFeed

final class NotificationsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func identifiedClient() async throws -> (GleanFeedClient, InMemoryTokenStore) {
        MockURLProtocol.handler = Fixtures.routeOK
        let store = InMemoryTokenStore()
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: store)
        try await client.identify(userId: "u1", email: "a@b.com", name: nil, signature: "sig")
        return (client, store)
    }

    func testUnreadCountReturnsServerValueWhenIdentified() async throws {
        let (client, _) = try await identifiedClient()
        MockURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/api/sdk/notifications") == true {
                return (200, Fixtures.json(#"{"unreadCount":7}"#))
            }
            return try Fixtures.routeOK(request)
        }

        let count = try await client.unreadCount()
        XCTAssertEqual(count, 7)
    }

    func testUnreadCountIsZeroWithoutIdentity() async throws {
        MockURLProtocol.handler = { _ in
            XCTFail("no request expected without an identity")
            return (200, Data())
        }
        let client = Fixtures.makeClient(session: MockURLProtocol.session(), store: InMemoryTokenStore())

        let count = try await client.unreadCount()
        XCTAssertEqual(count, 0)
    }

    func testUnreadCountIsZeroOnInvalidToken() async throws {
        let (client, _) = try await identifiedClient()
        MockURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/api/sdk/notifications") == true {
                return (401, Fixtures.json(#"{"error":"Invalid identity."}"#))
            }
            return try Fixtures.routeOK(request)
        }

        // A stale/invalid token is treated as signed-out — no user-visible error.
        let count = try await client.unreadCount()
        XCTAssertEqual(count, 0)
    }

    func testUnreadCountThrowsOnServerFailure() async throws {
        let (client, _) = try await identifiedClient()
        MockURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/api/sdk/notifications") == true {
                return (500, Fixtures.json(#"{"error":"boom"}"#))
            }
            return try Fixtures.routeOK(request)
        }

        do {
            _ = try await client.unreadCount()
            XCTFail("expected a server error to propagate")
        } catch let error as GleanFeedError {
            XCTAssertEqual(error, .server(statusCode: 500))
        }
    }

    func testNotificationsRequestEncodesExpectedFields() throws {
        let body = NotificationsRequest(workspaceId: "w1", userToken: "utoken")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
        XCTAssertEqual(json?["workspaceId"] as? String, "w1")
        XCTAssertEqual(json?["userToken"] as? String, "utoken")
        XCTAssertEqual(json?.keys.sorted(), ["userToken", "workspaceId"])
    }
}
