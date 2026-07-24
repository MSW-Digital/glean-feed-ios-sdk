#if canImport(UIKit)
import AuthenticationServices
import UIKit
import WebKit

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

/// Hosts a Glean Feed surface in a `WKWebView` with a loading indicator and a
/// failure/retry state. Resolves the surface URL via the configured client (SSO
/// handoff when identified, else anonymous), keeps portal navigation inside the
/// WebView, and hands external links to the system browser.
final class GleanFeedWebViewController: UIViewController {
    private let client: GleanFeedClient
    private let surface: GleanFeedView

    private var portalOrigin = ""
    private var loadTask: Task<Void, Never>?
    private var authTask: Task<Void, Never>?
    private var authenticationSession: ASWebAuthenticationSession?
    private var activeObserver: NSObjectProtocol?
    private var callbackObserver: NSObjectProtocol?
    private lazy var authMessageHandler = WeakScriptMessageHandler(delegate: self)

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(authMessageHandler, name: "gleanFeedAuth")
        // Tag the User-Agent so the Glean Feed portal renders its compact embed
        // shell instead of the full standalone site (the portal's
        // isNativeSdkRequest keys off this marker). Appended to the default UA.
        configuration.applicationNameForUserAgent = "GleanFeedSDK/\(GleanFeed.version)"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // The portal embed shell is a fixed 100vh column with a pinned bottom tab
        // bar. Constrain the WebView to the safe area (below) and stop the scroll
        // view from adding its own inset, so 100vh equals the visible height and
        // the tab bar stays pinned instead of falling below the fold.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private lazy var failureLabel: UILabel = {
        let label = UILabel()
        label.text = "Couldn’t load. Tap to retry."
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(reload)))
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(client: GleanFeedClient, surface: GleanFeedView) {
        self.client = client
        self.surface = surface
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        loadTask?.cancel()
        authTask?.cancel()
        authenticationSession?.cancel()
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        if let callbackObserver {
            NotificationCenter.default.removeObserver(callbackObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layoutSubviews()
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumePendingNativeAuth(delay: 0)
        }
        callbackObserver = NotificationCenter.default.addObserver(
            forName: .gleanFeedNativeAuthCallback,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumePendingNativeAuth(delay: 0)
        }
        reload()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            loadTask?.cancel()
            authTask?.cancel()
            authenticationSession?.cancel()
            webView.stopLoading()
        }
    }

    private func layoutSubviews() {
        [webView, failureLabel, spinner].forEach(view.addSubview)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failureLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failureLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            failureLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc private func reload() {
        failureLabel.isHidden = true
        webView.isHidden = false
        spinner.startAnimating()

        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await self.client.surfaceURL(for: self.surface)
                if Task.isCancelled { return }
                self.portalOrigin = gleanFeedOriginKey(url) ?? ""
                self.webView.load(URLRequest(url: url))
                self.resumePendingNativeAuth(delay: 0)
            } catch {
                if !Task.isCancelled { self.showFailure() }
            }
        }
    }

    private func showFailure() {
        spinner.stopAnimating()
        webView.isHidden = true
        failureLabel.isHidden = false
    }

    private func startNativeAuth(_ request: NativeAuthBridgeRequest) {
        authTask?.cancel()
        authenticationSession?.cancel()
        dispatchNativeAuthState(state: "starting", provider: request.provider)
        authTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pending = try await self.client.startNativeAuth(request)
                if Task.isCancelled { return }
                self.dispatchNativeAuthState(state: "pending", provider: pending.provider)
                if pending.provider == .google {
                    self.beginGoogleAuthentication(pending)
                }
            } catch {
                if !Task.isCancelled {
                    self.dispatchNativeAuthState(
                        state: "failed",
                        provider: request.provider,
                        message: self.authErrorMessage(error)
                    )
                }
            }
        }
    }

    private func beginGoogleAuthentication(_ pending: PendingNativeAuth) {
        guard let authorizationURL = pending.authorizationUrl,
              let callbackScheme = client.nativeAuthCallbackScheme
        else {
            dispatchNativeAuthState(
                state: "failed",
                provider: pending.provider,
                message: GleanFeedError.invalidResponse.localizedDescription
            )
            return
        }

        let session = ASWebAuthenticationSession(
            url: authorizationURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authenticationSession = nil
                if let callbackURL, self.client.handleNativeAuthCallback(callbackURL) {
                    self.resumePendingNativeAuth(delay: 0)
                    return
                }
                self.dispatchNativeAuthState(
                    state: "failed",
                    provider: pending.provider,
                    message: error == nil
                        ? GleanFeedError.invalidResponse.localizedDescription
                        : "Sign-in was cancelled."
                )
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authenticationSession = session
        if !session.start() {
            authenticationSession = nil
            dispatchNativeAuthState(
                state: "failed",
                provider: pending.provider,
                message: "Couldn’t open secure sign-in. Try again."
            )
        }
    }

    private func resumePendingNativeAuth(delay: Int) {
        guard !portalOrigin.isEmpty,
              client.pendingNativeAuth()?.callbackResult != nil,
              authenticationSession == nil
        else { return }
        authTask?.cancel()
        authTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                if Task.isCancelled { return }
            }
            await self.pollNativeAuthUntilComplete()
        }
    }

    private func pollNativeAuthUntilComplete() async {
        while !Task.isCancelled {
            do {
                let outcome = try await client.pollNativeAuth()
                switch outcome {
                case .complete(let authURL):
                    guard isTrustedNativeAuthHandoff(authURL, portalOrigin: portalOrigin) else {
                        throw GleanFeedError.invalidResponse
                    }
                    webView.load(URLRequest(url: authURL))
                    return
                case .pending(let interval):
                    try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                }
            } catch {
                if !Task.isCancelled {
                    dispatchNativeAuthState(
                        state: "failed",
                        provider: client.pendingNativeAuth()?.provider,
                        message: authErrorMessage(error)
                    )
                }
                return
            }
        }
    }

    private func dispatchNativeAuthState(
        state: String,
        provider: NativeAuthProvider?,
        message: String? = nil
    ) {
        var detail = ["state": state]
        if let provider { detail["provider"] = provider.rawValue }
        if let message { detail["message"] = message }
        guard let data = try? JSONSerialization.data(withJSONObject: detail),
              let json = String(data: data, encoding: .utf8)
        else { return }
        webView.evaluateJavaScript(
            "window.dispatchEvent(new CustomEvent('gleanfeed:native-auth-state',{detail:\(json)}));"
        )
    }

    private func authErrorMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Couldn’t complete sign-in. Try again."
    }
}

extension GleanFeedWebViewController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "gleanFeedAuth",
              let currentURL = webView.url,
              gleanFeedOriginKey(currentURL)?.caseInsensitiveCompare(portalOrigin) == .orderedSame,
              let request = client.nativeAuthBridgeRequest(from: message.body)
        else {
            dispatchNativeAuthState(
                state: "failed",
                provider: nil,
                message: "Native sign-in request was rejected."
            )
            return
        }
        startNativeAuth(request)
    }
}

extension GleanFeedWebViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? UIWindow()
    }
}

extension GleanFeedWebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        switch gleanFeedNavigationDecision(for: url, portalOrigin: portalOrigin) {
        case .allow:
            decisionHandler(.allow)
        case .openExternally:
            // Never load a non-portal navigation inside the SDK WebView — that's
            // how users get trapped. Cancel it, and hand off only user-safe web /
            // contact schemes to the system; ignore javascript:/data:/file: and
            // arbitrary app-scheme deep links coming from web content.
            decisionHandler(.cancel)
            if let scheme = url.scheme?.lowercased(),
               ["http", "https", "mailto", "tel"].contains(scheme) {
                UIApplication.shared.open(url)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showFailure()
    }
}
#endif
