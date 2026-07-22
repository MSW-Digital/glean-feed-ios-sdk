import Foundation

// Wire types for the `/api/sdk/*` contracts. Keys match the backend responses
// (camelCase) so no key-decoding strategy is needed.

struct IdentifyRequest: Encodable {
    let workspaceId: String
    let userId: String
    let email: String?
    let name: String?
    let signature: String
}

struct IdentifyResponse: Decodable {
    let userToken: String
    /// Short-lived, single-use SSO handoff token. Optional: anonymous-capable
    /// flows may omit it.
    let ssoToken: String?
}

struct DiagnosticsRequest: Encodable {
    let workspaceId: String
    let userToken: String
    /// Bounded, whitelisted metadata (see `DiagnosticsMetadata`).
    let metadata: [String: String]
}

struct NotificationsRequest: Encodable {
    let workspaceId: String
    let userToken: String
}

struct NotificationsResponse: Decodable {
    let unreadCount: Int
}

enum NativeAuthProvider: String, Codable {
  case google
  case magicLink = "magic_link"
}

struct NativeAuthStartRequest: Encodable {
  let callbackScheme: String
  let codeChallenge: String
  let email: String?
  let name: String?
  let provider: NativeAuthProvider
  let returnTo: String
  let workspaceId: String
  let workspaceSlug: String
}

struct NativeAuthStartResponse: Decodable {
  let authorizationUrl: URL?
  let expiresIn: Int
  let flowId: String
  let flowSecret: String
  let interval: Int
  let status: NativeAuthPollStatus
}

struct NativeAuthPollRequest: Encodable {
  let authorizationCode: String?
  let codeVerifier: String?
  let flowId: String
  let flowSecret: String
}

enum NativeAuthPollStatus: String, Codable {
  case authorizationPending = "authorization_pending"
  case complete
  case failed
}

struct NativeAuthPollResponse: Decodable {
  let authUrl: URL?
  let code: String?
  let interval: Int?
  let status: NativeAuthPollStatus
  let userToken: String?
}

struct PendingNativeAuth: Codable, Equatable {
  let authorizationUrl: URL?
  let authorizationCode: String?
  let callbackResult: String?
  let codeVerifier: String
  let expiresAt: Date
  let flowId: String
  let flowSecret: String
  let interval: Int
  let provider: NativeAuthProvider
  let returnTo: String
}

enum NativeAuthPollOutcome: Equatable {
  case complete(authUrl: URL)
  case pending(interval: Int)
}

/// Response of `GET /api/sdk/portal-url`.
struct PortalConfigResponse: Decodable {
    let workspaceSlug: String
    let portalBaseUrl: String
    let defaultView: String
    /// Keyed by view name plus `"portal"` (the root). Modeled as a dictionary so
    /// a new surface added server-side doesn't break decoding.
    let surfaces: [String: Surface]
    let ssoUrl: String
    let config: Branding

    struct Surface: Decodable {
        let url: String
        let returnTo: String
    }

    struct Branding: Decodable {
        let accentColor: String?
        // Optional so a workspace with branding unset never fails the whole
        // portal-config decode — surfaceURL doesn't need branding at all.
        let buttonIcon: String?
    }
}
