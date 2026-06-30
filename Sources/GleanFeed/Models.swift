import Foundation

// Wire types for the `/api/sdk/*` contracts. Keys match the backend responses
// (camelCase) so no key-decoding strategy is needed. See the Glean Feed repo:
// docs/api-contracts/ios-sdk.md.

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

/// Response of `GET /api/sdk/portal-url` (GF-211).
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
