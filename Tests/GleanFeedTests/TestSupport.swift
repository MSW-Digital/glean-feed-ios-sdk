import Foundation

@testable import GleanFeed

/// In-memory `TokenStore` so tests never touch the real Keychain (which isn't
/// available in a `swift test` host).
final class InMemoryTokenStore: TokenStore {
    private(set) var token: String?
    func saveUserToken(_ token: String) throws { self.token = token }
    func userToken() -> String? { token }
    func clear() throws { token = nil }
}

/// A stubbed `URLProtocol` that answers requests from a per-test handler keyed on
/// the request URL. Lets us drive the SDK's networking without a server.
final class MockURLProtocol: URLProtocol {
    /// Returns `(statusCode, jsonBody)` for a request, or throws to simulate a
    /// transport failure.
    static var handler: ((URLRequest) throws -> (Int, Data))?

    static func reset() { handler = nil }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

enum Fixtures {
    static func json(_ string: String) -> Data { Data(string.utf8) }

    static let identifyOK = json(#"{"userToken":"user-token-123","ssoToken":"sso-token-abc"}"#)

    /// Mirrors the GF-211 `/api/sdk/portal-url` response shape exactly.
    static let portalConfig = json(#"""
    {
      "workspaceSlug": "acme",
      "portalBaseUrl": "https://acme.gleanfeed.com",
      "defaultView": "feedback",
      "surfaces": {
        "feedback": { "url": "https://acme.gleanfeed.com/portal/acme/feedback", "returnTo": "/portal/acme/feedback" },
        "roadmap": { "url": "https://acme.gleanfeed.com/portal/acme/roadmap", "returnTo": "/portal/acme/roadmap" },
        "changelog": { "url": "https://acme.gleanfeed.com/portal/acme/changelog", "returnTo": "/portal/acme/changelog" },
        "portal": { "url": "https://acme.gleanfeed.com/portal/acme", "returnTo": "/portal/acme" }
      },
      "ssoUrl": "https://acme.gleanfeed.com/portal/acme/auth/sso",
      "config": { "accentColor": "#4285f4", "buttonIcon": "megaphone" }
    }
    """#)

    /// Routes to identify vs portal-url by path.
    static func routeOK(_ request: URLRequest) throws -> (Int, Data) {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/sdk/identify") { return (200, identifyOK) }
        if path.hasSuffix("/api/sdk/portal-url") { return (200, portalConfig) }
        throw URLError(.unsupportedURL)
    }

    static func makeClient(session: URLSession, store: TokenStore) -> GleanFeedClient {
        GleanFeedClient(
            configuration: GleanFeedConfiguration(
                workspaceId: "workspace-1",
                workspaceSlug: "acme",
                baseURL: URL(string: "https://gleanfeed.test")!
            ),
            session: session,
            tokenStore: store
        )
    }
}
