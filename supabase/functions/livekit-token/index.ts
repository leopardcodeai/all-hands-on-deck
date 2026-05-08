// Edge Function: livekit-token
// POST { session_id, participant_id }  ->  { token, url, room }
//
// Validates that the session is active and the participant belongs to it,
// then mints a short-lived LiveKit JWT scoped to that room.
//
// verify_jwt is disabled at the function level: the function does its own
// auth (session + participant validation against the database) using the
// service-role client.

import { AccessToken } from 'npm:livekit-server-sdk@2.15.2';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY') ?? '';
const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET') ?? '';
const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'method not allowed' });
  }

  // Fail fast with a clear message if the function has been deployed but the
  // operator forgot to set the LiveKit secrets.
  const missing = [
    ['SUPABASE_URL', SUPABASE_URL],
    ['SUPABASE_SERVICE_ROLE_KEY', SUPABASE_SERVICE_ROLE_KEY],
    ['LIVEKIT_API_KEY', LIVEKIT_API_KEY],
    ['LIVEKIT_API_SECRET', LIVEKIT_API_SECRET],
    ['LIVEKIT_URL', LIVEKIT_URL],
  ].filter(([, v]) => !v).map(([k]) => k);
  if (missing.length > 0) {
    return json(503, { error: `LiveKit beta is not configured: ${missing.join(', ')}` });
  }

  let payload: { session_id?: unknown; participant_id?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: 'invalid JSON body' });
  }

  const sessionId = typeof payload.session_id === 'string' ? payload.session_id.trim() : '';
  const participantId = typeof payload.participant_id === 'string' ? payload.participant_id.trim() : '';
  if (!sessionId || !participantId) {
    return json(400, { error: 'session_id and participant_id are required' });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const sessionQuery = admin.from('sessions').select('id, code, status');
  const { data: session, error: sessionError } = await (
    isUuid(sessionId) ? sessionQuery.eq('id', sessionId) : sessionQuery.eq('code', sessionId)
  ).maybeSingle();

  if (sessionError || !session || session.status !== 'active') {
    return json(404, { error: 'session not found' });
  }

  const participantQuery = admin
    .from('session_participants')
    .select('id, anonymous_id, session_id')
    .eq('session_id', session.id);
  const { data: participant, error: participantError } = await (
    isUuid(participantId)
      ? participantQuery.or(`id.eq.${participantId},anonymous_id.eq.${participantId}`)
      : participantQuery.eq('anonymous_id', participantId)
  ).maybeSingle();

  if (participantError || !participant) {
    return json(403, { error: 'participant is not in this session' });
  }

  // Token TTL: keep short to limit blast radius if the JWT leaks. Clients
  // are expected to re-fetch on connect rather than cache for hours.
  const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: participant.id,
    name: participant.anonymous_id ?? participant.id,
    ttl: 60 * 60, // 1 hour
  });
  token.addGrant({
    room: session.id,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return json(200, {
    token: await token.toJwt(),
    url: LIVEKIT_URL,
    room: session.id,
  });
});
