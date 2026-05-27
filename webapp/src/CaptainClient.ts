import { logger } from './lib/logger';
import { getSupabaseClient } from './lib/supabase';
import { createSession, type SessionBootstrap } from './services/sessionService';
import { subscribeToSessionRealtime } from './services/realtimeService';
import type { WireEvent, WireEnvelope, ParticipantDTO } from './wire';

type Listener = (state: CaptainState) => void;

export interface CaptainState {
  sessionCode: string;
  sessionId: string;
  status: 'idle' | 'creating' | 'active' | 'countdown' | 'captured' | 'ended';
  participants: ParticipantDTO[];
  countdownAt: number | null;
  finalPhotoBase64: string | null;
}

function uuid(): string {
  return globalThis.crypto.randomUUID();
}

export class CaptainClient {
  private bootstrap?: SessionBootstrap;
  private realtimeSub?: ReturnType<typeof subscribeToSessionRealtime>;
  private listeners = new Set<Listener>();
  private state: CaptainState;

  readonly participantId = uuid();

  constructor() {
    this.state = {
      sessionCode: '',
      sessionId: '',
      status: 'idle',
      participants: [],
      countdownAt: null,
      finalPhotoBase64: null,
    };
    logger.info('CaptainClient', 'Initialized', { participantId: this.participantId });
  }

  getState(): CaptainState { return this.state; }
  subscribe(l: Listener) { this.listeners.add(l); return () => this.listeners.delete(l); }
  private notify() { for (const l of this.listeners) l(this.state); }

  async startSession(displayName: string) {
    logger.info('CaptainClient', 'Starting session', { displayName });
    this.state = { ...this.state, status: 'creating' };
    this.notify();

    try {
      this.bootstrap = await createSession({
        hostName: displayName,
        anonymousId: this.participantId,
        peerId: this.participantId,
      });
      logger.info('CaptainClient', 'Session created', { code: this.bootstrap.session.code, id: this.bootstrap.session.id });

      this.state = {
        ...this.state,
        sessionCode: this.bootstrap.session.code,
        sessionId: this.bootstrap.session.id,
        status: 'active',
      };
      this.notify();

      this.realtimeSub = subscribeToSessionRealtime({
        sessionId: this.bootstrap.session.id,
        onEvent: (row) => this.handleEventRow(row),
        onParticipantsChanged: () => void this.refreshParticipants(),
        onPhotosChanged: () => {},
        onError: () => {
          logger.warn('CaptainClient', 'Realtime error');
        },
      });

      await this.send({
        sessionMetadata: {
          id: this.bootstrap.session.code,
          hostName: displayName,
          createdAt: new Date().toISOString(),
          expiresAt: this.bootstrap.session.expires_at ?? new Date(Date.now() + 600_000).toISOString(),
          timerDuration: 10,
          triggerPermission: 'everyoneCanStartTimer',
          isDiscoverableNearby: false,
          allowWebJoin: true,
          allowFinalPhotoDownload: true,
          participants: this.state.participants,
        },
      });
    } catch (e) {
      logger.error('CaptainClient', 'Session creation failed', { error: String(e) });
      throw e;
    }
  }

  async sendPreviewFrame(jpeg: string) {
    if (!jpeg) return;
    await this.send({ previewFrame: { jpeg, capturedAt: new Date().toISOString() } });
  }

  async sendFinalPhoto(jpeg: string) {
    logger.info('CaptainClient', 'Sending final photo', { size: jpeg.length });
    this.state = { ...this.state, finalPhotoBase64: jpeg, status: 'active' };
    this.notify();
    await this.send({ finalPhotoAvailable: { photoID: uuid(), jpeg } });
  }

  clearFinalPhoto() {
    this.state = { ...this.state, finalPhotoBase64: null };
    this.notify();
  }

  stop() {
    logger.info('CaptainClient', 'Stopping');
    this.realtimeSub?.unsubscribe();
    this.listeners.clear();
  }

  private async send(event: WireEvent) {
    if (!this.bootstrap) return;
    const type = Object.keys(event)[0];
    const env: WireEnvelope = {
      sessionId: this.state.sessionId,
      senderId: this.participantId,
      createdAt: new Date().toISOString(),
      event,
    };
    const clientGeneratedId = uuid();
    try {
      await getSupabaseClient()
        .from('session_events')
        .insert({
          session_id: this.bootstrap.session.id,
          sender_participant_id: this.bootstrap.participant.id,
          type,
          payload: env,
          client_generated_id: clientGeneratedId,
        });
    } catch (e) {
      logger.error('CaptainClient', 'Send failed', { type, error: String(e) });
    }
  }

  private handleEventRow(row: { payload?: unknown; type?: string }) {
    const env = row.payload as WireEnvelope | null;
    if (!env?.event || env.senderId === this.participantId) return;

    if ('captureRequested' in env.event || 'captureNowRequested' in env.event) {
      logger.info('CaptainClient', 'Capture requested by viewer', { type: Object.keys(env.event)[0] });
      this.listeners.forEach(l => l(this.state));
    }
  }

  private async refreshParticipants() {
    if (!this.bootstrap) return;
    const client = getSupabaseClient();
    const { data, error } = await client
      .from('session_participants')
      .select()
      .eq('session_id', this.bootstrap.session.id);
    if (error) {
      logger.error('CaptainClient', 'Failed to refresh participants', { error: String(error) });
      return;
    }
    if (data) {
      logger.info('CaptainClient', 'Participants refreshed', { count: data.length });
      this.state = {
        ...this.state,
        participants: data.map(p => ({
          id: p.anonymous_id ?? p.id,
          displayName: p.display_name ?? 'Crewmate',
          role: p.role as 'host' | 'viewer',
          joinedAt: p.joined_at,
          isReady: false,
          connectionType: 'web' as const,
        })),
      };
      this.notify();
    }
  }
}
