import SwiftUI

@main
struct AllHandsOnDeckApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var linkHandler = UniversalLinkHandler()

    init() {
        UINavigationBar.appearance().tintColor = UIColor(Theme.gold)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .environmentObject(linkHandler)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
                .task {
                    // Only authenticate if the user previously opted in; avoids GK log
                    // spam on devices where the entitlement isn't wired up yet.
                    guard UserDefaults.standard.bool(forKey: "identity.useGameCenter") else { return }
                    await GameCenterService.shared.authenticate()
                }
                .onOpenURL { url in
                    // Custom-scheme: allhands://join?session=ABC
                    linkHandler.handle(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Universal Link: https://allhands.leopardcode.ai/join/<id>
                    if let url = activity.webpageURL {
                        linkHandler.handle(url: url)
                    }
                }
        }
    }
}
