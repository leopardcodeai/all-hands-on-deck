# Contributing

## One-time setup

Requirements:
- Node 20+
- Xcode 16+ with iOS 17 simulator
- `brew install xcodegen` (re-generates `AllHandsOnDeck.xcodeproj` from `project.yml`)

```bash
( cd webapp && npm ci )
( cd server && npm ci )
xcodegen generate
```

## Local development

| Component | Command | Notes |
| --- | --- | --- |
| Relay server | `cd server && npm run dev` | Listens on `:8787`, hot-reloads via `tsx watch` |
| Web viewer  | `cd webapp && npm run dev` | Vite on `:5173`, bound to `0.0.0.0` so iPhones on the same LAN can reach it |
| iOS app     | `open AllHandsOnDeck.xcodeproj` | Set `webSocketServerURL` + `joinBaseURL` via the scheme's launch arguments |

The iOS host can run with the Mock or Multipeer transport without the relay
server; the relay is only needed for browser-based viewers.

## Test before opening a PR

```bash
# Webapp
( cd webapp && npm run typecheck && npm test && npm run build )

# Server
( cd server && npm run typecheck && npm test && npm run build )

# iOS
xcodegen generate
xcodebuild test \
  -project AllHandsOnDeck.xcodeproj \
  -scheme AllHandsOnDeck \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

CI runs all three on PR. Path filters mean only relevant suites trigger —
a webapp-only change won't queue an iOS build.

## Coding rules

- **Wire format is shared across iOS, web, and the relay.** When adding or
  renaming a `SessionEvent` case, update `webapp/src/wire.ts` *and*
  `webapp/src/sessionState.ts` in the same PR. The Vitest golden tests in
  `webapp/src/__tests__/wireFormat.test.ts` will fail loudly otherwise.
- **No new files at the root** unless they're build/deploy artifacts. New
  iOS code goes under the right `AllHandsOnDeck/{Models,Services,Views,…}/`
  subdir; XcodeGen picks them up on the next `xcodegen generate`.
- **No commits without tests for new pure logic.** Reducers, parsers, and
  routing primitives are easy to unit-test — please do.
- **Don't introduce secrets to the repo.** Firebase web config is
  client-side and intentionally public; everything else (Apple Team ID,
  Cloud Run service accounts) lives in deploy-time env vars or `.firebaserc`.

## Releasing

| Surface | How |
| --- | --- |
| Webapp + AASA | `firebase deploy --only hosting` (or full `./deploy.sh <gcp> <firebase>`) |
| Relay server | `gcloud run deploy` via `./deploy.sh` |
| iOS app | Xcode → Product → Archive → App Store Connect |
