# Supabase Setup

All Hands On Deck uses Supabase for persistent session data, Realtime fallback, Storage, and optional Auth.

## Feature Policy

Web Viewers are a **Beta** feature. The app shows a `BETA` badge next to
`Allow Web Viewers`, and the shared MVP policy records
`webViewersFeatureStage = beta`.

MVP limits:

- Supabase is the session backend, not the video backend.
- Video uses WebRTC/P2P first; no video bytes are stored in Supabase.
- Sessions expire after 10 minutes by default.
- P2P mode allows up to 3 web viewers per host.
- QR join tokens expire after 10 minutes.
- TURN is only used after explicit fallback and is capped.

## Environment Variables

Client-safe:

```bash
SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY=YOUR_ANON_KEY
VITE_SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_ANON_KEY
WEB_JOIN_BASE_URL=https://your-web-host.example.com
```

Server-only:

```bash
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
LIVEKIT_API_KEY=YOUR_LIVEKIT_KEY
LIVEKIT_API_SECRET=YOUR_LIVEKIT_SECRET
LIVEKIT_URL=wss://your-livekit-host
```

Never expose `SUPABASE_SERVICE_ROLE_KEY` or `LIVEKIT_API_SECRET` in the webapp or iOS app.

## Database Migration

Apply:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Migration file:

```text
supabase/migrations/20260505193000_initial_supabase_sessions.sql
supabase/migrations/20260506072500_app_85_p2p_mvp_controls.sql
```

It creates:

- `sessions`
- `participants`
- `photos`
- `session_events`
- RLS policies
- Realtime publication for `session_events`, `participants`, and `photos`
- private Storage bucket `photos`
- MVP policy columns including `web_viewers_feature_stage = beta`

## Storage

Bucket:

```text
photos
```

Path format:

```text
sessions/{session_id}/{photo_id}-{filename}
```

Uploads use the anon key and are allowed only for active sessions by RLS. For private delivery, create signed URLs server-side or through an authenticated client flow.

## Local Development

iOS config goes into `Secrets.xcconfig`:

```bash
cp Secrets.xcconfig.template Secrets.xcconfig
```

Webapp:

```bash
cd webapp
VITE_SUPABASE_URL=... VITE_SUPABASE_ANON_KEY=... npm run dev -- --host 0.0.0.0
```

Server:

```bash
cd server
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... npm run dev
```

## LiveKit Beta

Enable the beta UI:

```bash
VITE_ENABLE_LIVEKIT_BETA=true
```

The client calls:

```text
POST /api/livekit/token
```

The server validates that the participant belongs to the session, then signs the LiveKit token with `LIVEKIT_API_SECRET`. The main app works without LiveKit configured.

## Deployment

Build checks:

```bash
cd webapp && npm run build && npm test
cd server && npm run build && npm test
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Deploy the webapp by uploading `webapp/dist` to any static host. Set `WEB_JOIN_BASE_URL` in iOS to that public URL.
