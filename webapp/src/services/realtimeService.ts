import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../lib/supabase';

export interface SessionEventRow {
  id: string;
  session_id: string;
  sender_participant_id: string | null;
  type: string;
  payload: unknown;
  client_generated_id: string | null;
  created_at: string;
}

export interface RealtimeSubscription {
  unsubscribe: () => Promise<void>;
}

export class EventDeduper {
  private readonly keys = new Set<string>();
  private readonly maxEntries: number;

  constructor(maxEntries = 500) {
    this.maxEntries = maxEntries;
  }

  seen(event: Pick<SessionEventRow, 'id' | 'client_generated_id'>): boolean {
    const key = event.client_generated_id ? `client:${event.client_generated_id}` : `db:${event.id}`;
    if (this.keys.has(key)) return true;
    this.keys.add(key);
    if (this.keys.size > this.maxEntries) {
      const first = this.keys.values().next().value as string | undefined;
      if (first) this.keys.delete(first);
    }
    return false;
  }
}

export interface SubscribeSessionRealtimeInput {
  sessionId: string;
  client?: SupabaseClient;
  onEvent?: (event: SessionEventRow) => void;
  onParticipantsChanged?: () => void;
  onPhotosChanged?: () => void;
  onError?: (message: string) => void;
}

export function subscribeToSessionRealtime(input: SubscribeSessionRealtimeInput): RealtimeSubscription {
  const client = input.client ?? getSupabaseClient();
  const deduper = new EventDeduper();
  const channel: RealtimeChannel = client
    .channel(`session:${input.sessionId}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'session_events', filter: `session_id=eq.${input.sessionId}` },
      (payload) => {
        const event = payload.new as SessionEventRow;
        if (!deduper.seen(event)) input.onEvent?.(event);
      },
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'session_participants', filter: `session_id=eq.${input.sessionId}` },
      () => input.onParticipantsChanged?.(),
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'photos', filter: `session_id=eq.${input.sessionId}` },
      () => input.onPhotosChanged?.(),
    )
    .subscribe((status, error) => {
      if (error) input.onError?.(error.message);
      if (status === 'CHANNEL_ERROR') input.onError?.('Realtime channel disconnected.');
    });

  return {
    unsubscribe: async () => {
      await client.removeChannel(channel);
    },
  };
}
