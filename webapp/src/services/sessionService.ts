import type { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../lib/supabase';
import {
  DEFAULT_MVP_SESSION_POLICY,
  type JoinToken,
  canJoinP2PSession,
  createShortLivedJoinToken,
} from './sessionPolicy';

const SESSION_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const SESSION_CODE_LENGTH = 8;

export type SessionRole = 'host' | 'guest' | 'viewer';

export interface SessionRow {
  id: string;
  code: string;
  host_user_id: string | null;
  status: 'active' | 'ended' | 'expired';
  created_at: string;
  expires_at: string | null;
  join_token_expires_at?: string | null;
  max_viewers?: number | null;
  max_duration_minutes?: number | null;
  turn_minutes_used?: number | null;
  realtime_messages_per_minute?: number | null;
  metadata: Record<string, unknown>;
}

export interface ParticipantRow {
  id: string;
  session_id: string;
  user_id: string | null;
  anonymous_id: string | null;
  display_name: string | null;
  role: SessionRole;
  peer_id: string | null;
  livekit_identity: string | null;
  joined_at: string;
  last_seen_at: string;
}

export interface PhotoRow {
  id: string;
  session_id: string;
  uploaded_by: string | null;
  anonymous_id: string | null;
  storage_path: string;
  file_name: string | null;
  mime_type: string | null;
  width: number | null;
  height: number | null;
  size_bytes: number | null;
  created_at: string;
  metadata: Record<string, unknown>;
}

export interface CreateSessionInput {
  hostUserId?: string | null;
  hostName?: string | null;
  anonymousId?: string | null;
  peerId?: string | null;
  expiresAt?: string | null;
  metadata?: Record<string, unknown>;
  client?: SupabaseClient;
}

export interface JoinSessionInput {
  code: string;
  token?: string | null;
  anonymousId?: string | null;
  displayName?: string | null;
  peerId?: string | null;
  client?: SupabaseClient;
}

interface JoinTokenMetadata {
  value: string;
  expires_at: string;
  issued_at: string;
  session_id: string;
}

export interface SessionBootstrap {
  session: SessionRow;
  participant: ParticipantRow;
  participants: ParticipantRow[];
  photos: PhotoRow[];
  joinToken?: JoinToken;
}

export function normalizeSessionCode(code: string): string {
  return code.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function secureRandomFraction(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0] / (0xffffffff + 1);
}

export function createSessionCode(random: () => number = secureRandomFraction): string {
  let code = '';
  for (let i = 0; i < SESSION_CODE_LENGTH; i += 1) {
    const idx = Math.min(SESSION_ALPHABET.length - 1, Math.floor(random() * SESSION_ALPHABET.length));
    code += SESSION_ALPHABET[idx];
  }
  return code;
}

export function makePhotoStoragePath(sessionId: string, file: File, photoId: string = crypto.randomUUID()): string {
  const safeName = file.name
    .trim()
    .replace(/[/\\?%*:|"<>]/g, '-')
    .replace(/\s+/g, '-')
    || 'photo.jpg';
  return `sessions/${sessionId}/${photoId}-${safeName}`;
}

export async function createSession(input: CreateSessionInput = {}): Promise<SessionBootstrap> {
  const client = input.client ?? getSupabaseClient();
  const code = createSessionCode();
  const now = new Date();
  const expiresAt = input.expiresAt
    ?? new Date(now.getTime() + DEFAULT_MVP_SESSION_POLICY.maxSessionDurationMinutes * 60_000).toISOString();
  const provisionalToken = createShortLivedJoinToken('pending', now);

  const { data: session, error: sessionError } = await client
    .from('sessions')
    .insert({
      code,
      host_user_id: input.hostUserId ?? null,
      status: 'active',
      expires_at: expiresAt,
      join_token_expires_at: provisionalToken.expiresAt,
      max_viewers: DEFAULT_MVP_SESSION_POLICY.maxP2PViewers,
      max_duration_minutes: DEFAULT_MVP_SESSION_POLICY.maxSessionDurationMinutes,
      turn_minutes_used: 0,
      realtime_messages_per_minute: DEFAULT_MVP_SESSION_POLICY.realtimeMessagesPerMinute,
      web_viewers_feature_stage: DEFAULT_MVP_SESSION_POLICY.webViewersFeatureStage,
      metadata: {
        ...(input.metadata ?? {}),
        video_backend: 'webrtc_p2p',
        supabase_role: 'session_backend',
        video_storage: 'none',
        web_viewers_feature_stage: DEFAULT_MVP_SESSION_POLICY.webViewersFeatureStage,
      },
    })
    .select()
    .single();

  if (sessionError || !session) throw new Error(sessionError?.message ?? 'Could not create session.');

  const { data: participant, error: participantError } = await client
    .from('session_participants')
    .insert({
      session_id: session.id,
      user_id: input.hostUserId ?? null,
      anonymous_id: input.anonymousId ?? null,
      display_name: input.hostName ?? 'Host',
      role: 'host',
      peer_id: input.peerId ?? null,
      livekit_identity: input.anonymousId ?? input.hostUserId ?? null,
    })
    .select()
    .single();

  if (participantError || !participant) throw new Error(participantError?.message ?? 'Could not create host participant.');

  return {
    session: session as SessionRow,
    participant: participant as ParticipantRow,
    participants: [participant as ParticipantRow],
    photos: [],
    joinToken: { ...provisionalToken, sessionId: (session as SessionRow).id },
  };
}

export async function joinSession(input: JoinSessionInput): Promise<SessionBootstrap> {
  const client = input.client ?? getSupabaseClient();
  const code = normalizeSessionCode(input.code);

  const { data: session, error: sessionError } = await client
    .from('sessions')
    .select()
    .eq('code', code)
    .eq('status', 'active')
    .maybeSingle();

  if (sessionError) throw new Error(sessionError.message);
  if (!session) throw new Error('Session not found or no longer active.');

  const { data: existingViewers, error: existingViewersError } = await client
    .from('session_participants')
    .select()
    .eq('session_id', session.id)
    .eq('role', 'viewer');

  if (existingViewersError) throw new Error(existingViewersError.message);
  if (!canJoinP2PSession((existingViewers ?? []).length)) {
    throw new Error('This P2P session is full.');
  }

  if (session.join_token_expires_at && Date.parse(session.join_token_expires_at) < Date.now()) {
    throw new Error('Join QR code expired.');
  }

  const storedToken = (session.metadata as Record<string, unknown>)?.join_token as JoinTokenMetadata | undefined;
  if (storedToken?.value) {
    // If a join token is stored (e.g., from QR code), the input MUST provide a matching token.
    // This prevents unauthorized access to sessions that require a token.
    if (!input.token || storedToken.value !== input.token) {
      throw new Error('Invalid or missing join token.');
    }
  }

  const { data: participant, error: participantError } = await client
    .from('session_participants')
    .insert({
      session_id: session.id,
      anonymous_id: input.anonymousId ?? null,
      display_name: input.displayName ?? null,
      role: 'viewer',
      peer_id: input.peerId ?? null,
      livekit_identity: input.anonymousId ?? null,
    })
    .select()
    .single();

  if (participantError || !participant) throw new Error(participantError?.message ?? 'Could not join session.');

  const [{ data: participants, error: participantsError }, { data: photos, error: photosError }] = await Promise.all([
    client.from('session_participants').select().eq('session_id', session.id).order('joined_at', { ascending: true }),
    client.from('photos').select().eq('session_id', session.id).order('created_at', { ascending: false }),
  ]);

  if (participantsError) throw new Error(participantsError.message);
  if (photosError) throw new Error(photosError.message);

  return {
    session: session as SessionRow,
    participant: participant as ParticipantRow,
    participants: (participants ?? []) as ParticipantRow[],
    photos: (photos ?? []) as PhotoRow[],
  };
}
