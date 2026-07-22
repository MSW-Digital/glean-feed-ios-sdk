import CryptoKit
import Foundation
import Security

struct NativeAuthBridgeRequest {
  let email: String?
  let name: String?
  let provider: NativeAuthProvider
  let returnTo: String

  init?(body: Any, configuration: GleanFeedConfiguration) {
    guard
      let values = body as? [String: Any],
      values["action"] as? String == "start",
      values["workspaceSlug"] as? String == configuration.workspaceSlug,
      let providerValue = values["provider"] as? String,
      let provider = NativeAuthProvider(rawValue: providerValue),
      let returnTo = values["returnTo"] as? String,
      !returnTo.contains(".."),
      returnTo == "/portal/\(configuration.workspaceSlug)"
        || returnTo.hasPrefix("/portal/\(configuration.workspaceSlug)/")
    else {
      return nil
    }

    let email = (values["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = (values["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      email?.count ?? 0 <= 320,
      name?.count ?? 0 <= 120,
      provider != .magicLink || (email?.isEmpty == false)
    else {
      return nil
    }

    self.email = email?.isEmpty == false ? email : nil
    self.name = name?.isEmpty == false ? name : nil
    self.provider = provider
    self.returnTo = returnTo
  }
}

struct NativeAuthCallback: Equatable {
  let authorizationCode: String?
  let flowId: String
  let result: String
}

func parseNativeAuthCallback(_ url: URL, callbackScheme: String) -> NativeAuthCallback? {
  guard url.scheme?.caseInsensitiveCompare(callbackScheme) == .orderedSame,
    url.host == nil,
    url.path == "/gleanfeed-auth",
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
  else {
    return nil
  }
  var query = [String: String]()
  for item in components.queryItems ?? [] {
    guard let value = item.value, query[item.name] == nil else { return nil }
    query[item.name] = value
  }
  guard let flowId = query["flow"],
    let result = query["result"],
    ["complete", "error"].contains(result)
  else { return nil }
  let code = query["code"]
  guard (result == "complete" && isValidPKCEValue(code)) || (result == "error" && code == nil)
  else {
    return nil
  }
  return NativeAuthCallback(authorizationCode: code, flowId: flowId, result: result)
}

private func isValidPKCEValue(_ value: String?) -> Bool {
  guard let value, value.count == 43 else { return false }
  return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
}

func createNativeAuthCodeVerifier() throws -> String {
  var bytes = [UInt8](repeating: 0, count: 32)
  guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
    throw GleanFeedError.storage
  }
  return Data(bytes).base64URLEncodedString()
}

func nativeAuthCodeChallenge(_ verifier: String) -> String {
  Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
}

extension Data {
  fileprivate func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
