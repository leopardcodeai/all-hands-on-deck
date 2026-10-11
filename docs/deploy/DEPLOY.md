# Deploying the optional token server to Cloud Run

The server in this directory is a Node 22 HTTP + WebSocket server. The
endpoint the Vercel webapp can call is `POST /api/livekit/token`; the same
container also serves `/ws` for signaling and `/health` for liveness.

Region used throughout: **europe-west1**. Service name: **allhands-token**.

## 1. One-time prerequisites

Install [`gcloud`](https://cloud.google.com/sdk/docs/install) and pick a
project:

```sh
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

Enable the required APIs:

```sh
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com
```

Make sure billing is enabled on the project (Cloud Run free tier covers
typical dev usage but billing must be linked).

## 2. Create the secrets

The two values that must never live in the image:

```sh
printf '%s' 'YOUR_SUPABASE_SERVICE_ROLE_KEY' | \
  gcloud secrets create SUPABASE_SERVICE_ROLE_KEY --data-file=-

printf '%s' 'YOUR_LIVEKIT_API_SECRET' | \
  gcloud secrets create LIVEKIT_API_SECRET --data-file=-
```

To rotate later: `gcloud secrets versions add SUPABASE_SERVICE_ROLE_KEY --data-file=-`.

Grant the Cloud Run runtime service account read access:

```sh
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')
RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for SECRET in SUPABASE_SERVICE_ROLE_KEY LIVEKIT_API_SECRET; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${RUNTIME_SA}" \
    --role='roles/secretmanager.secretAccessor'
done
```

## 3. Deploy

The simplest path — Cloud Build builds the Dockerfile and deploys in one shot:

```sh
gcloud run deploy allhands-token \
  --source=server/ \
  --region=europe-west1 \
  --platform=managed \
  --allow-unauthenticated \
  --port=8080 \
  --set-env-vars=SUPABASE_URL=https://YOUR.supabase.co,LIVEKIT_API_KEY=YOUR_LIVEKIT_KEY,LIVEKIT_URL=wss://YOUR.livekit.cloud \
  --set-secrets=SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,LIVEKIT_API_SECRET=LIVEKIT_API_SECRET:latest
```

Cloud Run prints the service URL on success, e.g.
`https://allhands-token-xxxxxxxx-ew.a.run.app`.

`--allow-unauthenticated` is intentional: the endpoint validates
`(sessionId, participantId)` against Supabase before issuing a LiveKit
token, so opening it publicly is fine.

For a CI-driven build instead, use `cloudbuild.yaml`:

```sh
gcloud builds submit --config server/cloudbuild.yaml \
  --substitutions=_SUPABASE_URL=https://YOUR.supabase.co,_LIVEKIT_API_KEY=YOUR_KEY,_LIVEKIT_URL=wss://YOUR.livekit.cloud \
  server/
```

## 4. Wire the Vercel webapp to the deployed URL

The preferred MVP path is the Supabase Edge Function:

```text
VITE_LIVEKIT_TOKEN_ENDPOINT=https://YOUR-PROJECT-REF.supabase.co/functions/v1/livekit-token
```

If you deploy this optional Node server instead, set the Vercel environment
variable to its public Cloud Run URL:

```text
VITE_LIVEKIT_TOKEN_ENDPOINT=https://allhands-token-xxxxxxxx-ew.a.run.app/api/livekit/token
```

This requires CORS on the server if the endpoint is on a different origin from
the Vercel webapp.

## 5. Smoke test

```sh
URL=$(gcloud run services describe allhands-token --region=europe-west1 --format='value(status.url)')

# Health check
curl "$URL/health"

# Token endpoint (will return 404 unless the IDs exist in Supabase)
curl -X POST "$URL/api/livekit/token" \
  -H 'content-type: application/json' \
  -d '{"sessionId":"REAL_SESSION_UUID","participantId":"REAL_PARTICIPANT_UUID","role":"viewer"}'
```

A valid call returns `{ "token": "...", "url": "wss://..." }`.

## 6. Troubleshooting

- **503 / "Service Unavailable" on first request after deploy** — env vars
  missing. Check `gcloud run services describe allhands-token --region=europe-west1`
  and confirm `SUPABASE_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_URL` are set and
  the two secrets are mounted.
- **404 from `/api/livekit/token`** — the `(sessionId, participantId)`
  pair was not found in Supabase, or the row's status forbids joining.
  This is expected behavior, not a deployment problem.
- **403 on secret access** — the runtime service account is missing
  `roles/secretmanager.secretAccessor`. Re-run the binding step in section 2.
- **Logs** — `gcloud run services logs read allhands-token --region=europe-west1`.
