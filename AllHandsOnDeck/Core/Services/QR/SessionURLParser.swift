import Foundation

/// Extracts a session ID from anything a QR code (or paste buffer) might
/// contain. Accepts:
///
/// - `allhands://join?session=<id>`
/// - `https://<anything>/join/<id>`
/// - bare `<id>` (10–32 chars, alphanumeric)
enum SessionURLParser {
    struct JoinRequest: Equatable {
        let sessionID: String
        let token: String?
        let expiresAt: String?
    }

    static func joinRequest(from raw: String) -> JoinRequest? {
        guard let sessionID = sessionID(from: raw) else { return nil }
        guard let url = URL(string: raw),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return JoinRequest(sessionID: sessionID, token: nil, expiresAt: nil)
        }

        return JoinRequest(
            sessionID: sessionID,
            token: components.queryItems?.first(where: { $0.name == "token" })?.value,
            expiresAt: components.queryItems?.first(where: { $0.name == "expires_at" })?.value
        )
    }

    static func sessionID(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased() {
            // Custom scheme: allhands://join?session=ABCDE
            if scheme == "allhands" {
                if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let id = comps.queryItems?.first(where: { $0.name == "session" })?.value,
                   isPlausible(id) {
                    return id
                }
                let pathParts = url.pathComponents.filter { $0 != "/" }
                if url.host == "join",
                   let id = pathParts.first,
                   isPlausible(id) {
                    return id
                }
            }

            // Web link: https://allhands.captainleopard.app/join/<id>
            if scheme == "https" || scheme == "http" {
                let parts = url.pathComponents.filter { $0 != "/" }
                if let joinIdx = parts.firstIndex(of: "join"),
                   joinIdx + 1 < parts.count,
                   isPlausible(parts[joinIdx + 1]) {
                    return parts[joinIdx + 1]
                }
            }
        }

        // Plain text fallback: matches our PhotoSession.makeShortID alphabet.
        if isPlausible(trimmed) { return trimmed.uppercased() }
        return nil
    }

    private static func isPlausible(_ s: String) -> Bool {
        guard s.count >= 6, s.count <= 32 else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber }
    }
}
