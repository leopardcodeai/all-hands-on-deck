import { AccessToken } from 'livekit-server-sdk';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export interface LiveKitTokenInput {
  session_id?: unknown;
  participant_id?: unknown;
}

export interface LiveKitTokenEnv {
  SUPABASE_URL?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  LIVEKIT_API_KEY?: string;
  LIVEKIT_API_SECRET?: string;
  LIVEKIT_URL?: string;
}

export interface LiveKitTokenResult {
  status: number;
  body: Record<string, unknown>;
}

export async function createLiveKitToken(
  input: LiveKitTokenInput,
  env: LiveKitTokenEnv = process.env,
  supabase?: SupabaseClient,
): Promise<LiveKitTokenResult> {
  const sessionId = typeof input.session_id === 'string' ? input.session_id.trim() : '';
  const participantId = typeof input.participant_id === 'string' ? input.participant_id.trim() : '';

  if (!sessionId || !participantId) {
    return { status: 400, body: { error: 'session_id and participant_id are required' } };
  }

  const missing = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_URL']
    .filter((key) => !env[key as keyof LiveKitTokenEnv]);
  if (missing.length > 0) {
    return { status: 503, body: { error: `LiveKit beta is not configured: ${missing.join(', ')}` } };
  }

  const admin = supabase ?? createClient(env.SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  });

  const sessionQuery = admin.from('sessions').select('id, code, status');
  const { data: session, error: sessionError } = await (
    isUuid(sessionId) ? sessionQuery.eq('id', sessionId) : sessionQuery.eq('code', sessionId)
  ).maybeSingle();

  if (sessionError || !session || session.status !== 'active') {
    return { status: 404, body: { error: 'session not found' } };
  }

  const participantQuery = admin
    .from('participants')
    .select('id, anonymous_id, session_id')
    .eq('session_id', session.id);
  const { data: participant, error: participantError } = await (
    isUuid(participantId)
      ? participantQuery.or(`id.eq.${participantId},anonymous_id.eq.${participantId}`)
      : participantQuery.eq('anonymous_id', participantId)
  ).maybeSingle();

  if (participantError || !participant) {
    return { status: 403, body: { error: 'participant is not in this session' } };
  }

  const token = new AccessToken(env.LIVEKIT_API_KEY!, env.LIVEKIT_API_SECRET!, {
    identity: participant.id,
    name: participant.anonymous_id ?? participant.id,
  });
  token.addGrant({
    room: session.id,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return {
    status: 200,
    body: {
      token: await token.toJwt(),
      url: env.LIVEKIT_URL,
      room: session.id,
    },
  };
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
