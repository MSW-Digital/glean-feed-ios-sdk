#if canImport(UIKit)
import UIKit
import WebKit

/// Hosts a Glean Feed surface in a `WKWebView` with a native Done button (when
/// presented modally), a loading indicator, and a failure/retry state. Resolves
/// the surface URL via the configured client (SSO handoff when identified, else
/// anonymous), keeps portal navigation inside the WebView, and hands external
/// links to the system browser.
final class GleanFeedWebViewController: UIViewController {
    private let client: GleanFeedClient
    private let surface: GleanFeedView
    /// Modal presentation shows a Done button; a pushed controller relies on the
    /// navigation bar's back button instead.
    var showsDoneButton = true

    private var portalHost = ""
    private var loadTask: Task<Void, Never>?

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // Tag the User-Agent so the Glean Feed portal renders its compact embed
        // shell instead of the full standalone site (the portal's
        // isNativeSdkRequest keys off this marker). Appended to the default UA.
        configuration.applicationNameForUserAgent = "GleanFeedSDK/\(GleanFeed.version)"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
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

    deinit { loadTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if showsDoneButton {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done, target: self, action: #selector(done)
            )
        }
        layoutSubviews()
        reload()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            loadTask?.cancel()
            webView.stopLoading()
        }
    }

    private func layoutSubviews() {
        [webView, failureLabel, spinner].forEach(view.addSubview)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failureLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failureLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            failureLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
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
                self.portalHost = url.host ?? ""
                self.webView.load(URLRequest(url: url))
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

    @objc private func done() {
        dismiss(animated: true)
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
        switch gleanFeedNavigationDecision(for: url, portalHost: portalHost) {
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
