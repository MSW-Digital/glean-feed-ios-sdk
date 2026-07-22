import Foundation

/// Errors surfaced by the SDK. Descriptions never include tokens, signatures, or
/// other secrets.
public enum GleanFeedError: Error, Equatable {
    /// `GleanFeed.setup(...)` has not been called yet.
    case notConfigured
    /// The server response was missing or malformed.
    case invalidResponse
    /// Identity was rejected — invalid signature, or portal accounts disabled.
    case identityRejected
    /// The server returned an unexpected status code.
    case server(statusCode: Int)
    /// The request could not be completed (connectivity, timeout, cancellation).
    case network
    /// Persisting or clearing the user token failed.
    case storage
    /// A URL could not be constructed from the resolved configuration/response.
    case invalidURL
  /// Portal self-service auth requires a registered reverse-domain callback scheme.
  case nativeAuthNotConfigured
  /// The pending browser/email authorization was not completed before expiry.
  case nativeAuthExpired
  /// The browser/email provider rejected the pending authentication.
  case nativeAuthFailed(code: String)
}

extension GleanFeedError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "GleanFeed.setup(...) must be called before this operation."
        case .invalidResponse:
            return "The Glean Feed server returned an unexpected response."
        case .identityRejected:
            return "The provided identity was rejected."
        case .server(let statusCode):
            return "The Glean Feed server returned status \(statusCode)."
        case .network:
            return "The request could not be completed."
        case .storage:
            return "The Glean Feed user token could not be stored."
        case .invalidURL:
            return "A valid Glean Feed URL could not be constructed."
    case .nativeAuthNotConfigured:
      return "Native sign-in requires a registered callback URL scheme."
    case .nativeAuthExpired:
      return "The sign-in request expired. Start again."
    case .nativeAuthFailed(let code):
      switch code {
      case "accounts_disabled":
        return "Sign-in is not available for this portal."
      case "ambiguous_identity":
        return "This email cannot be matched to a single portal account."
      case "customer_limit":
        return "This portal is not accepting new members right now."
      default:
        return "Sign-in could not be completed. Try again."
      }
        }
    }
}
