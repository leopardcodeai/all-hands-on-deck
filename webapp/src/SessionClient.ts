import { db } from './firebase';
import { ref, onChildAdded, onValue, push, off, DatabaseReference, Unsubscribe } from 'firebase/database';
import type { WireEnvelope, WireEvent, PhotoSessionDTO } from './wire';

type Status = 'idle' | 'connecting' | 'connected' | 'lost' | 'ended' | 'notFound';
type Listener = (state: SessionClient) => void;

function uuid(): string {
  if ('randomUUID' in crypto) return crypto.randomUUID();
  return Math.random().toString(36).slice(2);
}

export class SessionClient {
  readonly sessionId: string;
  readonly participantId = uuid();

  status: Status = 'idle';
  metadata?: PhotoSessionDTO;
  latestFrameURL?: string;
  countdownTargetMs?: number;
  countdownDuration?: number;
  finalPhotoURL?: string;

  private lastFrameURL?: string;
  private listeners = new Set<Listener>();

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

  connect() {
    if (this.status !== 'idle') return;
    this.status = 'connecting';
    this.notify();

    const sessionRef = ref(db, `sessions/${this.sessionId}`);
    this.messagesRef = ref(db, `sessions/${this.sessionId}/messages`);
    this.frameRef    = ref(db, `sessions/${this.sessionId}/currentFrame`);

    // Announce ourselves to the host via messages.
    this.announceJoin();
    this.status = 'connected';
    this.notify();

    // Stream incoming messages (reactions from host, countdown, metadata, etc.)
    this.msgUnsub = onChildAdded(this.messagesRef, (snapshot) => {
      const env = snapshot.val() as WireEnvelope | null;
      if (!env?.event || env.senderId === this.participantId) return;
      this.handleEvent(env.event);
    });

    // Stream latest preview frame (host overwrites this node at ~3 fps).
    this.frameUnsub = onValue(this.frameRef, (snapshot) => {
      const env = snapshot.val() as WireEnvelope | null;
      if (!env?.event) return;
      const event = env.event;
      if ('previewFrame' in event) {
        this.applyFrame(event.previewFrame.jpeg);
        this.notify();
      }
    });
  }

  disconnect() {
    if (this.messagesRef && this.msgUnsub) { off(this.messagesRef); this.msgUnsub = undefined; }
    if (this.frameRef   && this.frameUnsub) { off(this.frameRef);   this.frameUnsub = undefined; }
    this.status = 'idle';
    this.notify();
  }

  // ── Outbound ───────────────────────────────────────────────────────────────

  sendCaptureRequest() {
    this.send({ captureRequested: { by: this.participantId } });
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
    if ('sessionMetadata' in event) {
      this.metadata = event.sessionMetadata;
    } else if ('countdownStarted' in event) {
      this.countdownTargetMs  = Date.parse(event.countdownStarted.photoAt);
      this.countdownDuration  = event.countdownStarted.duration;
    } else if ('countdownCancelled' in event) {
      this.countdownTargetMs = undefined;
    } else if ('photoCaptured' in event) {
      this.countdownTargetMs = undefined;
    } else if ('finalPhotoAvailable' in event) {
      this.applyFinalPhoto(event.finalPhotoAvailable.jpeg);
    } else if ('sessionEnded' in event) {
      this.status = 'ended';
    }
    this.notify();
  }

  private applyFrame(base64: string) {
    const blob = this.b64ToBlob(base64, 'image/jpeg');
    const url  = URL.createObjectURL(blob);
    if (this.lastFrameURL) URL.revokeObjectURL(this.lastFrameURL);
    this.lastFrameURL  = url;
    this.latestFrameURL = url;
  }

  private applyFinalPhoto(base64: string) {
    const blob = this.b64ToBlob(base64, 'image/jpeg');
    const url  = URL.createObjectURL(blob);
    if (this.finalPhotoURL) URL.revokeObjectURL(this.finalPhotoURL);
    this.finalPhotoURL = url;
  }

  private b64ToBlob(b64: string, type: string): Blob {
    const bin = atob(b64);
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new Blob([arr], { type });
  }
}
