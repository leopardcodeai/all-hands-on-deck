# `livekit-token` Edge Function

Mints a short-lived LiveKit JWT for a participant of an active session.

## Endpoint
`POST https://<your-project-ref>.supabase.co/functions/v1/livekit-token`

Body:
```json
{ "session_id": "<code or uuid>", "participant_id": "<anonymous_id or uuid>" }
```

Responses:
- `200 { token, url, room }` — JWT scoped to `room = session.id` (UUID).
- `400` — body validation failed.
- `403` — participant not in session.
- `404` — session not found / inactive.
- `503` — server-side LiveKit/Supabase env vars missing.

`verify_jwt` is **disabled** at the function level — the function does its own
auth (session + participant validation via the service-role client), so
clients can call it without an Authorization header.

## Required secrets (set in dashboard → Edge Functions → Secrets)
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by the platform.

## Deploy
```sh
supabase functions deploy livekit-token --no-verify-jwt
```
or via the Supabase MCP `deploy_edge_function` tool.
