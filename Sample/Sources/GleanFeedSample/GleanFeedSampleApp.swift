import GleanFeed
import SwiftUI

@main
struct GleanFeedSampleApp: App {
    init() {
        GleanFeed.setup(
            workspaceId: SampleConfig.workspaceId,
            workspaceSlug: SampleConfig.workspaceSlug,
            environment: SampleConfig.environment
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
