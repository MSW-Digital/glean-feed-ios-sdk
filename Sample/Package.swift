// swift-tools-version: 5.9

// GleanFeed sample app. This is a separate App package (App Playgrounds format)
// so `import AppleProductTypes` — which is Xcode-only — stays OUT of the root
// package, keeping the root `swift test` CI job working. Open this Sample folder
// in Xcode and run, or build it with `xcodebuild` (see docs/simulator-qa.md).
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "GleanFeedSample",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        .iOSApplication(
            name: "GleanFeedSample",
            targets: ["GleanFeedSample"],
            bundleIdentifier: "com.gleanfeed.sample",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.phone],
            supportedInterfaceOrientations: [.portrait]
        ),
    ],
    dependencies: [
        .package(name: "GleanFeed", path: "../"),
    ],
    targets: [
        .executableTarget(
            name: "GleanFeedSample",
            dependencies: [
                .product(name: "GleanFeed", package: "GleanFeed"),
            ],
            path: "Sources/GleanFeedSample"
        ),
    ]
)
