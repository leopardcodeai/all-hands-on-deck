import SwiftUI

@main
struct AllHandsOnDeckWatchApp: App {
    @StateObject private var bridge = WatchSideBridge()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(bridge)
        }
    }
}
