#if canImport(UIKit)
import UIKit

extension GleanFeed {
    /// Present the feedback surface as a sheet. Pass a presenter, or omit to use
    /// the top-most view controller. No-op (with a debug assertion) if `setup`
    /// wasn't called.
    @MainActor
    public static func showFeedback(from presenter: UIViewController? = nil) {
        present(.feedback, from: presenter)
    }

    /// Present the roadmap surface as a sheet.
    @MainActor
    public static func showRoadmap(from presenter: UIViewController? = nil) {
        present(.roadmap, from: presenter)
    }

    /// Present the changelog surface as a sheet.
    @MainActor
    public static func showChangelog(from presenter: UIViewController? = nil) {
        present(.changelog, from: presenter)
    }

    /// Push the feedback surface onto an existing navigation stack (relies on the
    /// nav bar's back button rather than a Done button).
    @MainActor
    public static func pushFeedback(onto navigationController: UINavigationController) {
        push(.feedback, onto: navigationController)
    }

    /// Push the roadmap surface onto an existing navigation stack.
    @MainActor
    public static func pushRoadmap(onto navigationController: UINavigationController) {
        push(.roadmap, onto: navigationController)
    }

    /// Push the changelog surface onto an existing navigation stack.
    @MainActor
    public static func pushChangelog(onto navigationController: UINavigationController) {
        push(.changelog, onto: navigationController)
    }

    @MainActor
    private static func present(_ surface: GleanFeedView, from presenter: UIViewController?) {
        guard let controller = makeController(for: surface) else { return }
        guard let host = presenter ?? topMostViewController() else { return }

        let navigation = UINavigationController(rootViewController: controller)
        // Standard card sheet on iPhone; use a detent-configured sheet later if
        // partial-height is wanted (iOS 15+).
        navigation.modalPresentationStyle = .pageSheet
        host.present(navigation, animated: true)
    }

    @MainActor
    private static func push(_ surface: GleanFeedView, onto navigationController: UINavigationController) {
        guard let controller = makeController(for: surface) else { return }
        controller.showsDoneButton = false
        navigationController.pushViewController(controller, animated: true)
    }

    @MainActor
    private static func makeController(for surface: GleanFeedView) -> GleanFeedWebViewController? {
        guard let client = shared else {
            assertionFailure("GleanFeed.setup(...) must be called before presenting a surface.")
            return nil
        }
        return GleanFeedWebViewController(client: client, surface: surface)
    }

    /// Best-effort top-most presented controller from the active foreground scene's
    /// key window. Used when the caller doesn't pass an explicit presenter.
    @MainActor
    static func topMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
