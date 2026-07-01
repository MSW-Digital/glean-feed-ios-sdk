#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// SwiftUI host for a Glean Feed surface — wraps the UIKit web view controller in
/// a navigation controller (for the Done button).
struct GleanFeedSurfaceView: UIViewControllerRepresentable {
    let surface: GleanFeedView

    func makeUIViewController(context: Context) -> UIViewController {
        guard let client = GleanFeed.shared else {
            assertionFailure("GleanFeed.setup(...) must be called before presenting a surface.")
            // Release builds skip the assertion — return a dismissable placeholder
            // instead of a blank, un-dismissable sheet.
            return UINavigationController(rootViewController: GleanFeedUnavailableViewController())
        }
        return UINavigationController(
            rootViewController: GleanFeedWebViewController(client: client, surface: surface)
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// Shown if a surface is requested before `GleanFeed.setup(...)` — a dismissable
/// message rather than a blank sheet.
final class GleanFeedUnavailableViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done)
        )

        let label = UILabel()
        label.text = "Glean Feed isn’t set up yet."
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc private func done() {
        dismiss(animated: true)
    }
}

public extension View {
    /// Present the Glean Feed **feedback** surface as a sheet bound to `isPresented`.
    func gleanFeedFeedback(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSurfaceView(surface: .feedback).ignoresSafeArea()
        }
    }

    /// Present the Glean Feed **roadmap** surface as a sheet bound to `isPresented`.
    func gleanFeedRoadmap(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSurfaceView(surface: .roadmap).ignoresSafeArea()
        }
    }

    /// Present the Glean Feed **changelog** surface as a sheet bound to `isPresented`.
    func gleanFeedChangelog(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSurfaceView(surface: .changelog).ignoresSafeArea()
        }
    }
}
#endif
