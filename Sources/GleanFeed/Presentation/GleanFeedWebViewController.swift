#if canImport(UIKit)
import UIKit
import WebKit

/// Hosts a Glean Feed surface in a `WKWebView` with a native Done button, a
/// loading indicator, and a failure/retry state. Resolves the surface URL via the
/// configured client (SSO handoff when identified, else anonymous), applies the
/// navigation policy, and opens external links in the system browser.
final class GleanFeedWebViewController: UIViewController {
    private let client: GleanFeedClient
    private let surface: GleanFeedView
    private var portalHost = ""

    private lazy var webView: WKWebView = {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
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
        label.text = "Couldn’t load. Pull to retry."
        label.textColor = .secondaryLabel
        label.textAlignment = .center
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done)
        )
        layoutSubviews()
        reload()
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
        ])
    }

    @objc private func reload() {
        failureLabel.isHidden = true
        webView.isHidden = false
        spinner.startAnimating()
        Task { @MainActor in
            do {
                let url = try await client.surfaceURL(for: surface)
                portalHost = url.host ?? ""
                webView.load(URLRequest(url: url))
            } catch {
                showFailure()
            }
        }
    }

    private func showFailure() {
        spinner.stopAnimating()
        webView.isHidden = true
        failureLabel.isHidden = false
    }

    @objc private func done() {
        presentingViewController?.dismiss(animated: true)
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
            // Only divert user-initiated link taps to the system browser; let
            // same-host redirects (which are .allow above) and other programmatic
            // navigations proceed so we don't strand the WebView mid-flow.
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            } else {
                decisionHandler(.allow)
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
