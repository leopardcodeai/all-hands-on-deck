import type { WireEnvelope, WireEvent, PhotoSessionDTO } from './wire';
import { applyEvent, initialState, type SessionState, type SessionStatus } from './sessionState';
import { joinSession, type ParticipantRow, type SessionBootstrap } from './services/sessionService';
import { subscribeToSessionRealtime, type RealtimeSubscription, type SessionEventRow } from './services/realtimeService';
import { getSupabaseClient } from './lib/supabase';
import { SessionPeer, type SessionPeerMessage } from './lib/p2p/sessionPeer';
import { SupabaseSessionSignaling } from './lib/p2p/supabaseSignaling';

type Status = SessionStatus;
type Listener = (state: SessionClient) => void;

function uuid(): string {
  if ('randomUUID' in crypto) return crypto.randomUUID();
  return Math.random().toString(36).slice(2);
}

export class SessionClient {
  readonly sessionId: string;
  readonly participantId = uuid();

  private state: SessionState = initialState;
  get status(): Status               { return this.state.status; }
  get metadata(): PhotoSessionDTO | undefined { return this.state.metadata; }
  get countdownTargetMs(): number | undefined { return this.state.countdownTargetMs; }
  get countdownDuration(): number | undefined { return this.state.countdownDuration; }

  latestFrameURL?: string;
  finalPhotoURL?: string;

  private lastFrameURL?: string;
  private listeners = new Set<Listener>();
  private frameListeners = new Set<(url: string) => void>();

  private bootstrap?: SessionBootstrap;
  private realtimeSub?: RealtimeSubscription;
  private peer?: SessionPeer;

  readonly displayName: string;

  constructor(sessionId: string, displayName: string) {
    this.sessionId = sessionId;
    this.displayName = displayName;
  }

  subscribe(l: Listener): () => void {
    this.listeners.add(l);
    return () => { this.listeners.delete(l); };
  }
  private notify() { for (const l of this.listeners) l(this); }

  /** Subscribe only to preview frame updates (fires at ~3fps; does not trigger general listeners). */
  subscribeFrame(l: (url: string) => void): () => void {
    this.frameListeners.add(l);
    return () => { this.frameListeners.delete(l); };
  }
  private notifyFrame(url: string) { for (const l of this.frameListeners) l(url); }

  async connect() {
    if (this.status !== 'idle') return;
    this.state = { ...this.state, status: 'connecting' };
    this.notify();

    try {
      this.bootstrap = await joinSession({
        code: this.sessionId,
        anonymousId: this.participantId,
        displayName: this.displayName,
        peerId: this.participantId,
      });
      this.applyBootstrap(this.bootstrap);

      this.realtimeSub = subscribeToSessionRealtime({
        sessionId: this.bootstrap.session.id,
        onEvent: (row) => this.handleEventRow(row),
        onParticipantsChanged: () => void this.refreshParticipants(),
        onPhotosChanged: () => void this.refreshPhotos(),
        onError: () => {
          this.state = { ...this.state, status: 'lost' };
          this.notify();
        },
      });

      this.startPeerSync(this.bootstrap);
      await this.announceJoin();
      this.state = { ...this.state, status: 'connected' };
      this.notify();
    } catch {
      this.state = { ...this.state, status: 'notFound' };
      this.notify();
    }
  }

  disconnect() {
    if (this.realtimeSub) {
      void this.realtimeSub.unsubscribe();
      this.realtimeSub = undefined;
    }
    this.peer?.cleanup();
    this.peer = undefined;
    this.clearFinalPhoto();
    this.bootstrap = undefined;
    this.state = { ...this.state, status: 'idle' };
    this.notify();
  }

  // ── Outbound ───────────────────────────────────────────────────────────────

  sendCaptureRequest() {
    this.send({ captureRequested: { by: this.participantId } });
  }

  sendCaptureNowRequest() {
    this.send({ captureNowRequested: { by: this.participantId } });
  }

  sendReady(ready: boolean) {
    this.send({ participantReadyChanged: { participantID: this.participantId, isReady: ready } });
  }

  sendReaction(reactionId: string) {
    this.send({ reactionSent: { by: this.participantId, reaction: reactionId } });
  }

  private async announceJoin() {
    await this.send({
      participantJoined: {
        id: this.participantId,
        displayName: this.displayName,
        role: 'viewer' as const,
        joinedAt: new Date().toISOString(),
        isReady: false,
        connectionType: 'web' as const,
      }
    });
  }

  private async send(event: WireEvent) {
    if (!this.bootstrap) return;
    const env: WireEnvelope = {
      sessionId: this.sessionId,
      senderId: this.participantId,
      createdAt: new Date().toISOString(),
      event,
    };
    this.peer?.sendWireEvent(event, this.sessionId);
    const clientGeneratedId = uuid();
    await getSupabaseClient()
      .from('session_events')
      .insert({
        session_id: this.bootstrap.session.id,
        sender_participant_id: this.bootstrap.participant.id,
        type: eventType(event),
        payload: env,
        client_generated_id: clientGeneratedId,
      });
  }

  // ── Inbound ────────────────────────────────────────────────────────────────

  private handleEvent(event: WireEvent) {
    const previousFinal = this.state.finalPhotoBase64;
    this.state = applyEvent(this.state, event);
    if (previousFinal && !this.state.finalPhotoBase64) {
      this.clearFinalPhoto();
    }
    if (this.state.finalPhotoBase64 && this.state.finalPhotoBase64 !== previousFinal) {
      this.applyFinalPhoto(this.state.finalPhotoBase64);
    }
    this.notify();
  }

  private handleEventRow(row: SessionEventRow) {
    const env = row.payload as WireEnvelope | null;
    if (!env?.event || env.senderId === this.participantId) return;
    if ('previewFrame' in env.event) {
      this.applyFrame(env.event.previewFrame.jpeg);
      return;
    }
    this.handleEvent(env.event);
  }

  private applyBootstrap(bootstrap: SessionBootstrap) {
    const metadata = bootstrap.session.metadata as Partial<PhotoSessionDTO>;
    const participants = participantRowsToDTOs(bootstrap.participants);
    this.state = {
      ...this.state,
      metadata: {
        id: bootstrap.session.code,
        hostName: typeof metadata.hostName === 'string' ? metadata.hostName : 'Host',
        createdAt: bootstrap.session.created_at,
        expiresAt: bootstrap.session.expires_at ?? new Date(Date.now() + 10 * 60 * 1000).toISOString(),
        timerDuration: typeof metadata.timerDuration === 'number' ? metadata.timerDuration : 10,
        triggerPermission: metadata.triggerPermission ?? 'everyoneCanStartTimer',
        isDiscoverableNearby: metadata.isDiscoverableNearby ?? true,
        allowWebJoin: metadata.allowWebJoin ?? true,
        allowFinalPhotoDownload: metadata.allowFinalPhotoDownload ?? true,
        participants,
      },
    };
  }

  private async refreshParticipants() {
    if (!this.bootstrap?.session.id) return;
    const { data, error } = await getSupabaseClient()
      .from('session_participants')
      .select()
      .eq('session_id', this.bootstrap.session.id)
      .order('joined_at', { ascending: true });
    if (error || !this.state.metadata) return;
    this.state = {
      ...this.state,
      metadata: {
        ...this.state.metadata,
        participants: participantRowsToDTOs((data ?? []) as ParticipantRow[]),
      },
    };
    this.notify();
  }

  private async refreshPhotos() {
    // Photo metadata is persisted for gallery views; current JoinPage still
    // renders final photos from wire events so this hook stays intentionally quiet.
  }

  private startPeerSync(bootstrap: SessionBootstrap) {
    if (typeof RTCPeerConnection === 'undefined') return;

    this.peer = new SessionPeer({
      sessionId: bootstrap.session.id,
      peerId: this.participantId,
      signaling: new SupabaseSessionSignaling(bootstrap.session.id),
      onMessage: (message) => this.handlePeerMessage(message),
      onConnectionState: (_peerId, state) => {
        if (state === 'failed' || state === 'disconnected') {
          this.state = { ...this.state, status: 'connected' };
          this.notify();
        }
      },
    });
    this.peer.start();

    for (const participant of bootstrap.participants) {
      const remotePeerId = participant.peer_id;
      if (remotePeerId && remotePeerId !== this.participantId) {
        void this.peer.connectToPeer(remotePeerId);
      }
    }
  }

  private handlePeerMessage(message: SessionPeerMessage) {
    if (message.type !== 'wire_event') return;
    const env = message.payload as WireEnvelope | null;
    if (!env?.event || env.senderId === this.participantId) return;
    if ('previewFrame' in env.event) {
      this.applyFrame(env.event.previewFrame.jpeg);
      return;
    }
    this.handleEvent(env.event);
  }

  private applyFrame(base64: string) {
    const blob = this.b64ToBlob(base64, 'image/jpeg');
    const url  = URL.createObjectURL(blob);
    if (this.lastFrameURL) URL.revokeObjectURL(this.lastFrameURL);
    this.lastFrameURL  = url;
    this.latestFrameURL = url;
    this.notifyFrame(url);
  }

  private applyFinalPhoto(base64: string) {
    const blob = this.b64ToBlob(base64, 'image/jpeg');
    const url  = URL.createObjectURL(blob);
    this.clearFinalPhoto();
    this.finalPhotoURL = url;
  }

  private clearFinalPhoto() {
    if (!this.finalPhotoURL) return;
    URL.revokeObjectURL(this.finalPhotoURL);
    this.finalPhotoURL = undefined;
  }

  private b64ToBlob(b64: string, type: string): Blob {
    const arr = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
    return new Blob([arr], { type });
  }
}

function eventType(event: WireEvent): string {
  return Object.keys(event)[0] ?? 'unknown';
}

function participantRowToDTO(row: ParticipantRow) {
  return {
    id: row.anonymous_id ?? row.id,
    displayName: row.display_name ?? 'Crewmate',
    role: row.role === 'host' ? 'host' as const : 'viewer' as const,
    joinedAt: row.joined_at,
    isReady: false,
    connectionType: 'web' as const,
  };
}

function participantRowsToDTOs(rows: ParticipantRow[]) {
  const participantsByIdentity = new Map<string, ReturnType<typeof participantRowToDTO>>();
  for (const row of rows) {
    participantsByIdentity.set(row.anonymous_id ?? row.id, participantRowToDTO(row));
  }
  return [...participantsByIdentity.values()];
}
