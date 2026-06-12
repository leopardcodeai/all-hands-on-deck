# CLAUDE.md — All Hands on Deck

Guidance for Claude Code (and other AI agents) working in this repo. Workflow rules, branch/PR conventions, and the work log live in [AGENTS.md](AGENTS.md); coding rules in [CONTRIBUTING.md](CONTRIBUTING.md). This file covers what you need to build, test, and not break.

## What this is

Live group-photo app: one iPhone is the camera ("Captain"), everyone else watches the live viewfinder — natively (Multipeer) or in the browser (Supabase), no install. iOS app in SwiftUI (iOS 17+, XcodeGen), webapp in Vite/React/TS, backend Supabase (Postgres + Realtime + Storage + Edge Functions).

## Build & test

```bash
# iOS — regenerate the project after any project.yml change
xcodegen generate
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild ... -only-testing:AllHandsOnDeckTests test   # unit tests

# Webapp
cd webapp && npm ci
npm run typecheck && npm test && npm run build
npx playwright test        # E2E (starts vite itself)
```

**Xcode beta machines:** if `xcode-select -p` points at CommandLineTools and only `/Applications/Xcode-beta.app` exists, prefix every `xcodebuild`/`xcrun` with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`. In Xcode 27 the simulator GUI app is **Device Hub** (`Xcode-beta.app/Contents/Applications/DeviceHub.app`), and `idb ui tap` no longer works (SimulatorKit.framework was removed) — drive the app via deep links (`allhands://join?session=<code>`) or GUI automation.

## Architecture in 60 seconds

- **Transports** (`AllHandsOnDeck/Core/Services/Session/`): `SessionTransport` protocol; `MultipeerSessionTransport` (nearby), `SupabaseSessionTransport` (web join), composed by `CompositeSessionTransport` via `SessionManager`. All share one wire envelope: `SessionWireMessage` (Swift) ↔ `webapp/src/wire.ts` (TS).
- **Preview frames** (~3 fps base64 JPEG) go over **Supabase Realtime Broadcast**, NOT the database. Contract: topic `session-frames:{sessions.id}` (UUID, not the 6-char code), event `preview_frame`, payload `{jpeg, capturedAt, senderId}`. Send = REST `POST {SUPABASE_URL}/realtime/v1/api/broadcast` (fire-and-forget). Receive = supabase-js channel (webapp `SessionClient.ts`) / Phoenix websocket client (iOS `SupabaseRealtimeFrameChannel.swift`). Do not reintroduce `previewFrame` INSERTs into `session_events` — that's exactly what this design removed (42 MB of frame rows at ~100 test sessions).
- **Control events** (countdown, capture, reactions, p2p signaling) go through the `session_events` table; a pg_cron job (`cleanup-session-events`, every 30 min) purges old rows.
- **Final photos**: Supabase Storage uploads + `photos` table; preview thumbnails still ride the event channel.
- **supabase-js channel gotcha**: `client.channel(topic)` returns the *existing* instance for a repeated topic; adding `postgres_changes` listeners to an already-subscribed channel throws (StrictMode remounts hit this). Postgres-changes channels therefore use a random topic suffix; broadcast channels must keep their exact topic — the name is the contract.

## Rules that bite

- All user-facing strings via `DesignLabels.swift` / `DesignLabels.ts` — never hardcode.
- Views hold no business logic; ViewModels coordinate; Services talk to the outside world; DI via protocols.
- Tests must be green before review; new transport/wire changes need Codable round-trip tests on both sides.
- Secrets live in `Secrets.xcconfig` (gitignored, template in `Secrets.xcconfig.template`) and `webapp/.env.local` — never commit them, never hardcode project URLs in code or docs.
- LiveKit was deliberately removed from main (`dd2b706`); the experiment lives on `feat/ui-i18n-hd-grace`. Don't resurrect it on main without being asked.
