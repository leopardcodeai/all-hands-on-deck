import Foundation

/// Static accessors for the LiveKit beta feature flag and Cloud Run token endpoint.
///
/// Both values come from Info.plist, which is fed by the xcconfig chain
/// (`Debug.xcconfig` → `Secrets.xcconfig`). When the token endpoint is empty
/// (the safe default), the beta is considered disabled regardless of the flag.
enum LiveKitConfig {
    private static func plistString(_ key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Absolute URL to the Cloud Run token endpoint, or `nil` if unset / malformed.
    /// Only accepts http/https schemes to prevent injection attacks.
    static var tokenEndpoint: URL? {
        let raw = plistString("LIVEKIT_TOKEN_ENDPOINT")
        guard !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme == "http" || url.scheme == "https" else {
            return nil
        }
        return url
    }

    /// True only when the build's xcconfig opts in AND a usable token endpoint is configured.
    /// The empty-endpoint guard means a stale `LIVEKIT_BETA_ENABLED=YES` can't surface the
    /// feature on a build that lacks the Cloud Run URL.
    static var isBetaEnabled: Bool {
        let flag = plistString("LIVEKIT_BETA_ENABLED").uppercased()
        guard flag == "YES" || flag == "TRUE" || flag == "1" else { return false }
        return tokenEndpoint != nil
    }

    // MARK: - Test helpers

    /// Pure helper used by unit tests so they can verify the gating logic without
    /// having to mutate the host bundle's Info.plist at runtime.
    /// Only accepts http/https schemes to prevent injection attacks.
    nonisolated static func evaluate(flagRaw: String, endpointRaw: String) -> Bool {
        let endpointTrimmed = endpointRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpointTrimmed.isEmpty,
              let url = URL(string: endpointTrimmed),
              url.scheme == "http" || url.scheme == "https"
        else {
            return false
        }
        let flag = flagRaw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return flag == "YES" || flag == "TRUE" || flag == "1"
    }
}
