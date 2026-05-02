import { db } from './firebase';
import { ref, onChildAdded, onValue, push, off, DatabaseReference, Unsubscribe } from 'firebase/database';
import type { WireEnvelope, WireEvent, PhotoSessionDTO } from './wire';
import { applyEvent, initialState, type SessionState, type SessionStatus } from './sessionState';

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

  // Firebase refs & unsubscribe handles
  private messagesRef?: DatabaseReference;
  private frameRef?: DatabaseReference;
  private msgUnsub?: Unsubscribe;
  private frameUnsub?: Unsubscribe;

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

  connect() {
    if (this.status !== 'idle') return;
    this.state = { ...this.state, status: 'connecting' };
    this.notify();

    this.messagesRef = ref(db, `sessions/${this.sessionId}/messages`);
    this.frameRef    = ref(db, `sessions/${this.sessionId}/currentFrame`);

    // Stream incoming messages BEFORE announcing join so we don't miss the host's
    // sessionMetadata reply that arrives immediately after participantJoined.
    this.msgUnsub = onChildAdded(this.messagesRef, (snapshot) => {
      const env = snapshot.val() as WireEnvelope | null;
      if (!env?.event || env.senderId === this.participantId) return;
      this.handleEvent(env.event);
    });

    // Announce after listeners are attached so the host's reply is never missed.
    this.announceJoin();
    this.state = { ...this.state, status: 'connected' };
    this.notify();

    // Stream latest preview frame (host overwrites this node at ~3 fps).
    this.frameUnsub = onValue(this.frameRef, (snapshot) => {
      const env = snapshot.val() as WireEnvelope | null;
      if (!env?.event) return;
      const event = env.event;
      if ('previewFrame' in event) {
        this.applyFrame(event.previewFrame.jpeg);
        // Frame updates go to subscribeFrame listeners only — not general listeners —
        // so JoinPage doesn't re-render at 3fps from frames.
      }
    });
  }

  disconnect() {
    if (this.messagesRef && this.msgUnsub) { off(this.messagesRef); this.msgUnsub = undefined; }
    if (this.frameRef   && this.frameUnsub) { off(this.frameRef);   this.frameUnsub = undefined; }
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

  private announceJoin() {
    this.send({
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

  private send(event: WireEvent) {
    if (!this.messagesRef) return;
    const env: WireEnvelope = {
      sessionId: this.sessionId,
      senderId: this.participantId,
      createdAt: new Date().toISOString(),
      event,
    };
    push(this.messagesRef, env);
  }

  // ── Inbound ────────────────────────────────────────────────────────────────

  private handleEvent(event: WireEvent) {
    const previousFinal = this.state.finalPhotoBase64;
    this.state = applyEvent(this.state, event);
    if (this.state.finalPhotoBase64 && this.state.finalPhotoBase64 !== previousFinal) {
      this.applyFinalPhoto(this.state.finalPhotoBase64);
    }
    this.notify();
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
    if (this.finalPhotoURL) URL.revokeObjectURL(this.finalPhotoURL);
    this.finalPhotoURL = url;
  }

  private b64ToBlob(b64: string, type: string): Blob {
    const arr = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
    return new Blob([arr], { type });
  }
}
