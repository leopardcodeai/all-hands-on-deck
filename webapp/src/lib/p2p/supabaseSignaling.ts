import type { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../supabase';
import type { SignalMessage, SessionPeerSignaling } from './sessionPeer';

export class SupabaseSessionSignaling implements SessionPeerSignaling {
  constructor(
    private readonly sessionId: string,
    private readonly client: SupabaseClient = getSupabaseClient(),
  ) {}

  async sendSignal(signal: SignalMessage): Promise<void> {
    await this.client.from('session_events').insert({
      session_id: this.sessionId,
      type: 'p2p_signal',
      payload: signal,
      client_generated_id: signal.id,
    });
  }

  subscribeSignals(peerId: string, handler: (signal: SignalMessage) => void): () => void {
    // Random suffix: supabase-js reuses channel instances per topic, and
    // re-adding postgres_changes listeners to a subscribed channel throws
    // (StrictMode remounts race the async removeChannel). The filter does
    // not depend on the topic name.
    const channel = this.client
      .channel(`signals:${this.sessionId}:${peerId}:${Math.random().toString(36).slice(2, 8)}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'session_events', filter: `session_id=eq.${this.sessionId}` },
        (payload) => {
          const row = payload.new as { type?: string; payload?: unknown };
          if (row.type !== 'p2p_signal') return;
          const signal = row.payload as SignalMessage;
          if (signal.targetPeerId === peerId) handler(signal);
        },
      )
      .subscribe();

    return () => {
      void this.client.removeChannel(channel);
    };
  }
}
