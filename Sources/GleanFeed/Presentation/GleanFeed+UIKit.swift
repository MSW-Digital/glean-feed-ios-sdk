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

    @MainActor
    private static func present(_ surface: GleanFeedView, from presenter: UIViewController?) {
        guard let client = shared else {
            assertionFailure("GleanFeed.setup(...) must be called before presenting a surface.")
            return
        }
        guard let host = presenter ?? topMostViewController() else { return }

        let controller = GleanFeedWebViewController(client: client, surface: surface)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet // full-height sheet
        host.present(navigation, animated: true)
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
