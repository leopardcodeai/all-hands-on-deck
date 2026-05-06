#!/usr/bin/env bash
# deploy.sh — All Hands on Deck server deployment helper.
# The webapp is now a static Vite build and can be deployed to any static host
# using the generated webapp/dist directory.

set -euo pipefail

GCP_PROJECT="${1:?Usage: ./deploy.sh <gcp-project-id> [region]}"
REGION="${2:-europe-west3}"

SERVICE_NAME="allhands-server"
IMAGE="gcr.io/${GCP_PROJECT}/${SERVICE_NAME}"

echo "==> [1/4] Setting GCP project to ${GCP_PROJECT}"
gcloud config set project "${GCP_PROJECT}"

echo "==> [2/4] Building & pushing Docker image"
gcloud builds submit --tag "${IMAGE}" .

echo "==> [3/4] Deploying to Cloud Run (region: ${REGION})"
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --allow-unauthenticated \
  --port 8787 \
  --memory 256Mi \
  --timeout 3600 \
  --min-instances 0 \
  --max-instances 3 \
  --set-env-vars "PORT=8787,NODE_ENV=production"

SERVER_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region "${REGION}" \
  --format "value(status.url)")

echo "==> [4/4] Building webapp"
cd webapp
npm run build
cd ..

echo ""
echo "Deployment build complete."
echo ""
echo "   Server          : ${SERVER_URL}"
echo "   Webapp artifact : webapp/dist"
echo ""
echo "Set WEB_JOIN_BASE_URL to your static hosting URL and deploy webapp/dist with:"
echo "   VITE_SUPABASE_URL"
echo "   VITE_SUPABASE_ANON_KEY"
echo "   VITE_ENABLE_LIVEKIT_BETA=true   # optional"
