import Foundation

#if os(iOS)
import WebKit
#endif

func gleanFeedPortalHosts(from origins: Set<String>) -> Set<String> {
    Set(origins.compactMap { URL(string: $0)?.host?.lowercased() })
}

func gleanFeedShouldClearCookieDomain(_ cookieDomain: String, portalHosts: Set<String>) -> Bool {
    let domain = cookieDomain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    guard !domain.isEmpty else { return false }
    if portalHosts.contains(domain) { return true }
    return domain == "gleanfeed.com" && portalHosts.contains { $0 == domain || $0.hasSuffix(".\(domain)") }
}

func clearGleanFeedPortalSession(for origins: Set<String>) async {
#if os(iOS)
    let portalHosts = gleanFeedPortalHosts(from: origins)
    guard !portalHosts.isEmpty else { return }

    #if compiler(>=6.0)
    let cookieStore = await WKWebsiteDataStore.default().httpCookieStore
    #else
    let cookieStore = WKWebsiteDataStore.default().httpCookieStore
    #endif
    for cookie in await cookieStore.gleanfeed_allCookies()
    where gleanFeedShouldClearCookieDomain(cookie.domain, portalHosts: portalHosts) {
        await cookieStore.gleanfeed_delete(cookie)
    }
#else
    _ = origins
#endif
}

#if os(iOS)
private extension WKHTTPCookieStore {
    func gleanfeed_allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { continuation.resume(returning: $0) }
        }
    }

    func gleanfeed_delete(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            delete(cookie) { continuation.resume() }
        }
    }
}
#endif
