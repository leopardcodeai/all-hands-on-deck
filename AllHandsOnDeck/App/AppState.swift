import Foundation

/// Process-wide app state. Step 1 holds little — kept as the seam for nav state,
/// active-session pointers, and feature flags as the app grows.
@MainActor
final class AppState: ObservableObject {
    @Published var activeHostSessionID: String?
}
