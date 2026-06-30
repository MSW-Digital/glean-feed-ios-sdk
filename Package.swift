// swift-tools-version: 5.9
import PackageDescription

// Glean Feed iOS SDK (beta). Modern toolchain (5.9), deploying to iOS 14 — the
// platforms floor sets the deployment target, not the toolchain, so we target
// iOS 14 without carrying old Swift-tools debt. No third-party dependencies;
// the SDK uses only Foundation, WebKit, SwiftUI/UIKit, Security, and URLSession.
let package = Package(
    name: "GleanFeed",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(name: "GleanFeed", targets: ["GleanFeed"]),
    ],
    targets: [
        .target(name: "GleanFeed"),
        .testTarget(name: "GleanFeedTests", dependencies: ["GleanFeed"]),
    ]
)
