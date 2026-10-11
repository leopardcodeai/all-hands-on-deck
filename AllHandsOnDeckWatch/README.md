# Watch App Setup

The Watch companion runs as a separate target inside the same `AllHandsOnDeck.xcodeproj`. Xcode requires you to add the target through its UI — there's no plain-files way to create one.

## One-time setup

1. Open `AllHandsOnDeck.xcodeproj` in Xcode.
2. **File → New → Target → watchOS → App**.
   - Product name: `AllHandsOnDeckWatch`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Bundle Identifier: `<your-iOS-bundle-id>.watchkitapp`
   - Embed In: pick the iOS app target so the watch app is paired with it.
3. Xcode generates a `AllHandsOnDeckWatch Watch App/` group with a stub
   `AllHandsOnDeckWatchApp.swift` and `ContentView.swift`. **Delete those two
   stubs**.
4. Drag every file under this directory (`AllHandsOnDeckWatch/`) into the
   Watch App target group:
   - `App/AllHandsOnDeckWatchApp.swift`
   - `Services/WatchSideBridge.swift`
   - `Views/WatchRootView.swift`
   - Make sure their target membership is **only** the Watch App target.
5. Add the **shared** protocol file
   `AllHandsOnDeck/Services/Watch/WatchProtocol.swift`
   to **both** targets (File Inspector → Target Membership: tick both).
6. Capabilities — neither side needs special entitlements for WCSession.
7. Build: select the Watch App scheme, pair an Apple Watch (real or
   Simulator), Run.

## Test flow

- iPhone: open the app, start a host session (web-join optional, doesn't
  matter for the watch).
- Watch: launches into the live remote view automatically, since
  `WCSession` activates on app start.
- Tap "Timer 10s" on the wrist → phone starts the countdown. Both
  devices count down in sync (watch uses `TimelineView` against the
  same `photoAt` epoch the phone publishes).
- Tap "Jetzt" → phone captures immediately.
- During countdown the watch shows the big number and an "Abbrechen"
  button.

## Limits

- No preview frames on the watch — too expensive, screen too small.
- Watch only works while paired and within Bluetooth/WiFi range of the
  phone. WCSession `transferUserInfo` queues snapshots when the watch
  sleeps, so brief disconnects are fine.
- If the phone foregrounds and the watch hasn't received a snapshot yet,
  the wrist UI shows the "no session" state until the next snapshot
  arrives. The watch can poke `requestSnapshot` to force one.
