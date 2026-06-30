#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI

/// SwiftUI host for a Glean Feed surface — wraps the UIKit web view controller in
/// a navigation controller (for the Done button).
struct GleanFeedSurfaceView: UIViewControllerRepresentable {
    let surface: GleanFeedView

    func makeUIViewController(context: Context) -> UIViewController {
        guard let client = GleanFeed.shared else {
            assertionFailure("GleanFeed.setup(...) must be called before presenting a surface.")
            return UIViewController()
        }
        return UINavigationController(
            rootViewController: GleanFeedWebViewController(client: client, surface: surface)
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
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
