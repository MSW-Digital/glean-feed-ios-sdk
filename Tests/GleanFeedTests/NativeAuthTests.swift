import XCTest

@testable import GleanFeed

final class NativeAuthTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.reset()
    super.tearDown()
  }

  func testCallbackSchemeRequiresReverseDomainNotation() {
    XCTAssertTrue(isValidNativeAuthCallbackScheme("com.example.customer-app"))
    XCTAssertTrue(isValidNativeAuthCallbackScheme("com.msw-digital.sample"))

    XCTAssertFalse(isValidNativeAuthCallbackScheme("gleanfeed"))
    XCTAssertFalse(isValidNativeAuthCallbackScheme("https"))
    XCTAssertFalse(isValidNativeAuthCallbackScheme("javascript"))
    XCTAssertFalse(isValidNativeAuthCallbackScheme("com.example.app\r\nhttps"))
  }

  func testNativeAuthCallbackCarriesOnlyAOneTimeCodeForTheExpectedApp() {
    let code = String(repeating: "c", count: 43)
    let callback = parseNativeAuthCallback(
      URL(
        string: "com.example.customer-app:/gleanfeed-auth?flow=flow-1&result=complete&code=\(code)")!,
      callbackScheme: "com.example.customer-app"
    )

    XCTAssertEqual(
      callback,
      NativeAuthCallback(authorizationCode: code, flowId: "flow-1", result: "complete")
    )
    XCTAssertNil(
      parseNativeAuthCallback(
        URL(string: "com.example.customer-app:/gleanfeed-auth?flow=flow-1&result=complete")!,
        callbackScheme: "com.example.customer-app"
      )
    )
    XCTAssertNil(
      parseNativeAuthCallback(
        URL(string: "com.attacker.app:/gleanfeed-auth?flow=flow-1&result=complete&code=\(code)")!,
        callbackScheme: "com.example.customer-app"
      )
    )
    XCTAssertNil(
      parseNativeAuthCallback(
        URL(
          string:
            "com.example.customer-app:/gleanfeed-auth?flow=flow-1&flow=other&result=complete&code=\(code)"
        )!,
        callbackScheme: "com.example.customer-app"
      )
    )
  }

  func testPKCEChallengeIsBoundToTheAppHeldVerifier() throws {
    XCTAssertEqual(try createNativeAuthCodeVerifier().count, 43)
    XCTAssertEqual(nativeAuthCodeChallenge(String(repeating: "v", count: 43)).count, 43)
    XCTAssertNotEqual(
      nativeAuthCodeChallenge(String(repeating: "v", count: 43)),
      nativeAuthCodeChallenge(String(repeating: "w", count: 43))
    )
  }

  func testBridgeAcceptsOnlyThisWorkspaceAndPortalReturnPath() {
    let configuration = GleanFeedConfiguration(
      workspaceId: "workspace-1",
      workspaceSlug: "acme",
      callbackURLScheme: "com.example.customer-app",
      baseURL: URL(string: "https://gleanfeed.test")!
    )
    let request = NativeAuthBridgeRequest(
      body: [
        "action": "start",
        "email": "Person@Example.com",
        "name": "Person",
        "provider": "magic_link",
        "returnTo": "/portal/acme/feedback",
        "workspaceSlug": "acme",
      ],
      configuration: configuration
    )

    XCTAssertEqual(request?.provider, .magicLink)
    XCTAssertEqual(request?.email, "Person@Example.com")
    XCTAssertEqual(request?.returnTo, "/portal/acme/feedback")

    XCTAssertNil(
      NativeAuthBridgeRequest(
        body: [
          "action": "start",
          "provider": "google",
          "returnTo": "/portal/other/feedback",
          "workspaceSlug": "other",
        ],
        configuration: configuration
      )
    )
    XCTAssertNil(
      NativeAuthBridgeRequest(
        body: [
          "action": "start",
          "provider": "google",
          "returnTo": "/portal/acme/../../admin",
          "workspaceSlug": "acme",
        ],
        configuration: configuration
      )
    )
  }

  func testNativeAuthWireModelsUseBoundedPublicContract() throws {
    let start = NativeAuthStartRequest(
      callbackScheme: "com.example.customer-app",
      codeChallenge: String(repeating: "p", count: 43),
      email: "person@example.com",
      name: "Person",
      provider: .magicLink,
      returnTo: "/portal/acme/feedback",
      workspaceId: "workspace-1",
      workspaceSlug: "acme"
    )
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(start)) as? [String: Any]
    )
    XCTAssertEqual(json["provider"] as? String, "magic_link")
    XCTAssertEqual(json["callbackScheme"] as? String, "com.example.customer-app")
    XCTAssertEqual(json["codeChallenge"] as? String, String(repeating: "p", count: 43))
    XCTAssertEqual(json["workspaceId"] as? String, "workspace-1")

    let pending = try JSONDecoder().decode(
      NativeAuthPollResponse.self,
      from: Fixtures.json(#"{"status":"authorization_pending","interval":5}"#)
    )
    XCTAssertEqual(pending.status, .authorizationPending)
    XCTAssertEqual(pending.interval, 5)

    let complete = try JSONDecoder().decode(
      NativeAuthPollResponse.self,
      from: Fixtures.json(
        #"{"status":"complete","authUrl":"https://acme.gleanfeed.com/auth/oauth-finish?token=one-time","userToken":"user-token"}"#
      )
    )
    XCTAssertEqual(complete.status, .complete)
    XCTAssertEqual(complete.userToken, "user-token")
    XCTAssertEqual(complete.authUrl?.host, "acme.gleanfeed.com")
  }

  func testAPIClientStartsAndPollsNativeAuthentication() async throws {
    var requestedPaths: [String] = []
    MockURLProtocol.handler = { request in
      let path = request.url?.path ?? ""
      requestedPaths.append(path)
      if path == "/api/sdk/auth/start" {
        return (
          201,
          Fixtures.json(
            #"{"status":"authorization_pending","flowId":"flow-1","flowSecret":"device-secret","expiresIn":1200,"interval":5,"authorizationUrl":"https://app.gleanfeed.com/api/sdk/auth/google/start?token=one-time"}"#
          )
        )
      }
      if path == "/api/sdk/auth/poll" {
        return (
          200,
          Fixtures.json(
            #"{"status":"complete","authUrl":"https://acme.gleanfeed.com/auth/oauth-finish?token=handoff","userToken":"user-token"}"#
          )
        )
      }
      throw URLError(.unsupportedURL)
    }

    let api = APIClient(
      baseURL: URL(string: "https://gleanfeed.test")!,
      session: MockURLProtocol.session()
    )
    let start = try await api.startNativeAuth(
      NativeAuthStartRequest(
        callbackScheme: "com.example.customer-app",
        codeChallenge: String(repeating: "p", count: 43),
        email: nil,
        name: nil,
        provider: .google,
        returnTo: "/portal/acme/feedback",
        workspaceId: "workspace-1",
        workspaceSlug: "acme"
      )
    )
    let complete = try await api.pollNativeAuth(
      NativeAuthPollRequest(
        authorizationCode: String(repeating: "c", count: 43),
        codeVerifier: String(repeating: "v", count: 43),
        flowId: start.flowId,
        flowSecret: start.flowSecret
      )
    )

    XCTAssertEqual(requestedPaths, ["/api/sdk/auth/start", "/api/sdk/auth/poll"])
    XCTAssertEqual(start.authorizationUrl?.host, "app.gleanfeed.com")
    XCTAssertEqual(complete.status, .complete)
    XCTAssertEqual(complete.userToken, "user-token")
  }

  func testClientPersistsFlowBeforeReturningBrowserAuthorizationURL() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.path, "/api/sdk/auth/start")
      return (
        201,
        Fixtures.json(
          #"{"status":"authorization_pending","flowId":"flow-1","flowSecret":"device-secret","expiresIn":1200,"interval":5,"authorizationUrl":"https://app.gleanfeed.com/api/sdk/auth/google/start?token=one-time"}"#
        )
      )
    }
    let store = InMemoryTokenStore()
    let client = nativeAuthClient(store: store)
    let bridge = try XCTUnwrap(
      NativeAuthBridgeRequest(
        body: [
          "action": "start",
          "provider": "google",
          "returnTo": "/portal/acme/feedback",
          "workspaceSlug": "acme",
        ],
        configuration: nativeAuthConfiguration
      )
    )

    let pending = try await client.startNativeAuth(bridge)

    XCTAssertEqual(pending.authorizationUrl?.host, "app.gleanfeed.com")
    XCTAssertEqual(store.pendingNativeAuth(), pending)
  }

  func testClientConsumesCompletedFlowIntoWebViewURLAndUserToken() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.path, "/api/sdk/auth/poll")
      return (
        200,
        Fixtures.json(
          #"{"status":"complete","authUrl":"https://acme.gleanfeed.com/auth/oauth-finish?token=handoff","userToken":"user-token"}"#
        )
      )
    }
    let store = InMemoryTokenStore()
    try store.savePendingNativeAuth(
      PendingNativeAuth(
        authorizationUrl: nil,
        authorizationCode: String(repeating: "c", count: 43),
        callbackResult: "complete",
        codeVerifier: String(repeating: "v", count: 43),
        expiresAt: Date().addingTimeInterval(1200),
        flowId: "flow-1",
        flowSecret: "device-secret",
        interval: 5,
        provider: .magicLink,
        returnTo: "/portal/acme/feedback"
      )
    )
    let client = nativeAuthClient(store: store)

    let outcome = try await client.pollNativeAuth()

    XCTAssertEqual(
      outcome,
      .complete(
        authUrl: URL(
          string: "https://acme.gleanfeed.com/auth/oauth-finish?token=handoff"
        )!
      )
    )
    XCTAssertEqual(store.userToken(), "user-token")
    XCTAssertNil(store.pendingNativeAuth())
    XCTAssertTrue(client.isIdentified)
  }

  func testTeamCompletionClearsAStaleEndUserToken() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.path, "/api/sdk/auth/poll")
      return (
        200,
        Fixtures.json(
          #"{"status":"complete","authUrl":"https://acme.gleanfeed.com/auth/oauth-finish?token=team-handoff"}"#
        )
      )
    }
    let store = InMemoryTokenStore()
    try store.saveUserToken("stale-end-user-token")
    try store.savePendingNativeAuth(
      PendingNativeAuth(
        authorizationUrl: nil,
        authorizationCode: String(repeating: "c", count: 43),
        callbackResult: "complete",
        codeVerifier: String(repeating: "v", count: 43),
        expiresAt: Date().addingTimeInterval(1200),
        flowId: "flow-1",
        flowSecret: "device-secret",
        interval: 5,
        provider: .google,
        returnTo: "/portal/acme/feedback"
      )
    )

    _ = try await nativeAuthClient(store: store).pollNativeAuth()

    XCTAssertNil(store.userToken())
  }

  func testClientAcceptsCallbackOnlyForItsPersistedPKCEFlow() throws {
    let store = InMemoryTokenStore()
    try store.savePendingNativeAuth(
      PendingNativeAuth(
        authorizationUrl: nil,
        authorizationCode: nil,
        callbackResult: nil,
        codeVerifier: String(repeating: "v", count: 43),
        expiresAt: Date().addingTimeInterval(1200),
        flowId: "flow-1",
        flowSecret: "device-secret",
        interval: 5,
        provider: .magicLink,
        returnTo: "/portal/acme/feedback"
      )
    )
    let client = nativeAuthClient(store: store)
    let code = String(repeating: "c", count: 43)

    XCTAssertFalse(
      client.handleNativeAuthCallback(
        URL(
          string: "com.example.customer-app:/gleanfeed-auth?flow=other&result=complete&code=\(code)"
        )!
      )
    )
    XCTAssertTrue(
      client.handleNativeAuthCallback(
        URL(
          string:
            "com.example.customer-app:/gleanfeed-auth?flow=flow-1&result=complete&code=\(code)")!
      )
    )
    XCTAssertEqual(store.pendingNativeAuth()?.authorizationCode, code)
    XCTAssertEqual(store.pendingNativeAuth()?.callbackResult, "complete")
  }

  private var nativeAuthConfiguration: GleanFeedConfiguration {
    GleanFeedConfiguration(
      workspaceId: "workspace-1",
      workspaceSlug: "acme",
      callbackURLScheme: "com.example.customer-app",
      baseURL: URL(string: "https://gleanfeed.test")!
    )
  }

  private func nativeAuthClient(store: TokenStore) -> GleanFeedClient {
    GleanFeedClient(
      configuration: nativeAuthConfiguration,
      session: MockURLProtocol.session(),
      tokenStore: store
    )
  }
}
