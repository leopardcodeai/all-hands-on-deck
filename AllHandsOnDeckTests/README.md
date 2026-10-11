# Test Target Setup

XCTest target setup is one Xcode-wizard step Apple doesn't let you bypass with files alone.

## One-time

1. Xcode → File → New → Target → iOS → **Unit Testing Bundle**.
2. Product Name: `AllHandsOnDeckTests`. Target to be tested:
   `AllHandsOnDeck`.
3. Xcode generates an empty `AllHandsOnDeckTests/AllHandsOnDeckTests.swift`
   stub. **Delete it.**
4. Drag every file in this folder into the new target group:
   - `CountdownCoordinatorTests.swift`
   - `SessionURLParserTests.swift`
   - `SessionWireMessageTests.swift`
   - `PhotoSessionTests.swift`
   - `NearbySessionSummaryTests.swift`
   - `MockSessionTransportTests.swift`
   - `ImageCompressionTests.swift`
   - Confirm Target Membership: **only** `AllHandsOnDeckTests`.

5. The tests use `@testable import AllHandsOnDeck`, so the App target must
   be set to `Defines Module = Yes` (it is by default for SwiftUI templates).

## Running

- ⌘U from any scheme that includes the test target.
- Or `xcodebuild test -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Tests are deterministic (no network, no camera) and complete in <2s.

## What's covered

| Suite | What it locks down |
| --- | --- |
| `CountdownCoordinatorTests` | State transitions, target-Date math, isActive truth table |
| `SessionURLParserTests` | All 3 URL forms + edge cases + garbage input |
| `SessionWireMessageTests` | Codable round-trip, kind classifier, large preview-frame blob |
| `PhotoSessionTests` | ID alphabet (no ambiguous chars), 10k uniqueness, joinURL override |
| `NearbySessionSummaryTests` | discoveryInfo decoding, fallback values, makePhotoSession |
| `MockSessionTransportTests` | Broker isolation by sessionID, no self-echo, status publisher |
| `ImageCompressionTests` | Downscale actually shrinks, garbage input is passthrough |

## What's *not* covered

- AVFoundation paths (`CameraService`, `QRScannerView`) — need real camera hardware.
- MultipeerConnectivity (`MultipeerSessionTransport`) — needs two devices on the same network.
- WebSocket transport — needs the Node server running.
- Vision (`InFrameDetector`, `PhotoQualityScorer`) — feasible to add with checked-in fixture JPEGs; deferred to keep the test target lightweight.

These are all integration paths that would either flake in CI or require fixture data we don't ship. Run the README's Step-by-Step test plans manually for those.
