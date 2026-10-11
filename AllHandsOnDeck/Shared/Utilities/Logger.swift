import Foundation
import os

/// Lightweight wrapper around os.Logger so call sites stay terse.
enum AppLog {
    static let app = Logger(subsystem: "app.captainleopard.allhands", category: "app")
    static let camera = Logger(subsystem: "app.captainleopard.allhands", category: "camera")
    static let session = Logger(subsystem: "app.captainleopard.allhands", category: "session")
    static let transport = Logger(subsystem: "app.captainleopard.allhands", category: "transport")
    static let countdown = Logger(subsystem: "app.captainleopard.allhands", category: "countdown")
}
