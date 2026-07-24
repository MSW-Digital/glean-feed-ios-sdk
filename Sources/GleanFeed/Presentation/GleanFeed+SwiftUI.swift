#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// SwiftUI host for a Glean Feed surface.
struct GleanFeedSurfaceView: UIViewControllerRepresentable {
    let surface: GleanFeedView

    func makeUIViewController(context: Context) -> UIViewController {
        guard let client = GleanFeed.shared else {
            assertionFailure("GleanFeed.setup(...) must be called before presenting a surface.")
            // Release builds skip the assertion — return a visible placeholder
            // instead of a blank sheet. The containing sheet stays drag-dismissable.
            return GleanFeedUnavailableViewController()
        }
        return GleanFeedWebViewController(client: client, surface: surface)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private struct GleanFeedSheetContent: View {
    let surface: GleanFeedView

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, *) {
            GleanFeedSurfaceView(surface: surface)
                .ignoresSafeArea()
                .presentationDragIndicator(.visible)
        } else {
            GleanFeedSurfaceView(surface: surface)
                .ignoresSafeArea()
        }
    }
}

/// Shown if a surface is requested before `GleanFeed.setup(...)` — a dismissable
/// message rather than a blank sheet.
final class GleanFeedUnavailableViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

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
}

public extension View {
    /// Present the Glean Feed **feedback** surface as a sheet bound to `isPresented`.
    func gleanFeedFeedback(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSheetContent(surface: .feedback)
        }
    }

    /// Present the Glean Feed **roadmap** surface as a sheet bound to `isPresented`.
    func gleanFeedRoadmap(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSheetContent(surface: .roadmap)
        }
    }

    /// Present the Glean Feed **changelog** surface as a sheet bound to `isPresented`.
    func gleanFeedChangelog(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            GleanFeedSheetContent(surface: .changelog)
        }
    }
}
#endif
