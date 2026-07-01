import Foundation

/// Bounded, whitelisted app/device metadata for `/api/sdk/diagnostics`. Only the
/// four fields the backend keeps are ever collected — no logs, screenshots,
/// arbitrary dictionaries, URLs, tokens, emails, names, or feedback text. The
/// collector is Foundation-only (no UIKit) so it's unit-testable off-device.
struct DiagnosticsMetadata: Equatable {
    let platform = "ios"
    let appVersion: String?
    let osVersion: String
    let sdkVersion: String

    /// Whitelisted wire payload. `appVersion` is omitted when unavailable.
    var payload: [String: String] {
        var payload = [
            "platform": platform,
            "osVersion": osVersion,
            "sdkVersion": sdkVersion,
        ]
        if let appVersion, !appVersion.isEmpty {
            payload["appVersion"] = appVersion
        }
        return payload
    }

    /// Collect from the current process/bundle. Injectable for tests.
    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        sdkVersion: String = GleanFeed.version
    ) -> DiagnosticsMetadata {
        let os = processInfo.operatingSystemVersion
        return DiagnosticsMetadata(
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            sdkVersion: sdkVersion
        )
    }
}
