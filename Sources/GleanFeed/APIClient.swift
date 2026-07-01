import Foundation

/// Thin `URLSession` wrapper for the Glean Feed `/api/sdk/*` endpoints. No
/// third-party dependencies; request builders are small and unit-testable via a
/// mocked `URLProtocol`.
struct APIClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func identify(_ body: IdentifyRequest) async throws -> IdentifyResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/sdk/identify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw GleanFeedError.invalidResponse
        }
        // 401 (bad signature / identity mismatch) and 403 (accounts disabled) are
        // both "identity rejected" from the caller's point of view.
        return try await send(request) { $0 == 401 || $0 == 403 ? .identityRejected : nil }
    }

    /// Fire-and-forget: any 2xx is success. The `{received:true}` body is ignored,
    /// so a best-effort diagnostics call never fails on an unexpected body shape.
    func diagnostics(_ body: DiagnosticsRequest) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/sdk/diagnostics"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw GleanFeedError.invalidResponse
        }
        try await perform(request) { _ in nil }
    }

    func portalConfig(workspaceSlug: String, view: GleanFeedView) async throws -> PortalConfigResponse {
        guard
            var components = URLComponents(
                url: baseURL.appendingPathComponent("api/sdk/portal-url"),
                resolvingAgainstBaseURL: false
            )
        else {
            throw GleanFeedError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "workspace", value: workspaceSlug),
            URLQueryItem(name: "view", value: view.rawValue),
        ]
        guard let url = components.url else { throw GleanFeedError.invalidURL }
        return try await send(URLRequest(url: url)) { _ in nil }
    }

    /// Sends a request and returns the 2xx body. `mapClientError` lets a caller
    /// turn a specific status code into a typed error; otherwise non-2xx becomes
    /// `.server(statusCode:)`.
    @discardableResult
    private func perform(
        _ request: URLRequest,
        mapClientError: (Int) -> GleanFeedError?
    ) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.gleanfeed_data(for: request)
        } catch {
            throw GleanFeedError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw GleanFeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapClientError(http.statusCode) ?? .server(statusCode: http.statusCode)
        }
        return data
    }

    /// Sends a request and decodes the 2xx body as `T`.
    private func send<T: Decodable>(
        _ request: URLRequest,
        mapClientError: (Int) -> GleanFeedError?
    ) async throws -> T {
        let data = try await perform(request, mapClientError: mapClientError)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GleanFeedError.invalidResponse
        }
    }
}

extension URLSession {
    /// iOS 14-compatible `async` data fetch. `URLSession.data(for:)` is iOS 15+,
    /// so bridge the completion-handler API through a continuation. (Cancellation
    /// is not propagated to the task; acceptable for v1's short requests.)
    func gleanfeed_data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
    }
}
