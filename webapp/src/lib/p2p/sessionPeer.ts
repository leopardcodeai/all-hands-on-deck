import type { WireEnvelope, WireEvent } from '../../wire';
import { DEFAULT_MVP_SESSION_POLICY, shouldUseTurnFallback } from '../../services/sessionPolicy';

export type SessionPeerEventType =
  | 'participant_joined'
  | 'participant_left'
  | 'photo_added'
  | 'photo_removed'
  | 'host_changed'
  | 'heartbeat'
  | 'sync_request'
  | 'sync_state'
  | 'wire_event'
  | 'signal';

export interface SessionPeerMessage {
  id: string;
  type: SessionPeerEventType;
  senderId: string;
  createdAt: string;
  payload: unknown;
}

export interface SignalMessage {
  id: string;
  sessionId: string;
  senderPeerId: string;
  targetPeerId: string;
  kind: 'offer' | 'answer' | 'ice';
  payload: RTCSessionDescriptionInit | RTCIceCandidateInit;
  createdAt: string;
}

export interface SessionPeerSignaling {
  sendSignal(signal: SignalMessage): Promise<void>;
  subscribeSignals(peerId: string, handler: (signal: SignalMessage) => void): () => void;
}

export interface SessionPeerOptions {
  sessionId: string;
  peerId: string;
  signaling: SessionPeerSignaling;
  iceServers?: RTCIceServer[];
  onMessage?: (message: SessionPeerMessage) => void;
  onConnectionState?: (peerId: string, state: RTCPeerConnectionState) => void;
  retryDelayMs?: number;
  explicitTurnFallbackRequested?: boolean;
  usedTurnMinutes?: number;
}

interface PeerSlot {
  connection: RTCPeerConnection;
  channel?: RTCDataChannel;
  retryCount: number;
}

export class SessionPeer {
  private readonly peers = new Map<string, PeerSlot>();
  private readonly seen = new Set<string>();
  private unsubscribeSignals?: () => void;
  private closed = false;

  constructor(private readonly options: SessionPeerOptions) {}

  start() {
    this.unsubscribeSignals = this.options.signaling.subscribeSignals(this.options.peerId, (signal) => {
      void this.handleSignal(signal);
    });
  }

  async connectToPeer(remotePeerId: string): Promise<void> {
    const slot = this.getOrCreateSlot(remotePeerId);
    const channel = slot.connection.createDataChannel('session-events', { ordered: true });
    this.attachChannel(remotePeerId, channel);
    const offer = await slot.connection.createOffer();
    await slot.connection.setLocalDescription(offer);
    await this.sendSignal(remotePeerId, 'offer', offer);
  }

  broadcast(type: SessionPeerEventType, payload: unknown) {
    const message: SessionPeerMessage = {
      id: crypto.randomUUID(),
      type,
      senderId: this.options.peerId,
      createdAt: new Date().toISOString(),
      payload,
    };
    this.markSeen(message.id);
    const encoded = JSON.stringify(message);
    for (const slot of this.peers.values()) {
      if (slot.channel?.readyState === 'open') slot.channel.send(encoded);
    }
  }

  sendWireEvent(event: WireEvent, sessionId: string = this.options.sessionId) {
    const envelope: WireEnvelope = {
      sessionId,
      senderId: this.options.peerId,
      createdAt: new Date().toISOString(),
      event,
    };
    this.broadcast('wire_event', envelope);
  }

  cleanup() {
    this.closed = true;
    this.unsubscribeSignals?.();
    for (const slot of this.peers.values()) {
      slot.channel?.close();
      slot.connection.close();
    }
    this.peers.clear();
    this.seen.clear();
  }

  private getOrCreateSlot(remotePeerId: string): PeerSlot {
    const existing = this.peers.get(remotePeerId);
    if (existing) return existing;

    const connection = new RTCPeerConnection({
      iceServers: this.options.iceServers ?? this.defaultIceServers(),
    });
    const slot: PeerSlot = { connection, retryCount: 0 };
    this.peers.set(remotePeerId, slot);

    connection.onicecandidate = (event) => {
      if (event.candidate) void this.sendSignal(remotePeerId, 'ice', event.candidate.toJSON());
    };
    connection.ondatachannel = (event) => this.attachChannel(remotePeerId, event.channel);
    connection.onconnectionstatechange = () => {
      this.options.onConnectionState?.(remotePeerId, connection.connectionState);
      if (connection.connectionState === 'failed' || connection.connectionState === 'disconnected') {
        this.retry(remotePeerId);
      }
    };
    return slot;
  }

  private attachChannel(remotePeerId: string, channel: RTCDataChannel) {
    const slot = this.getOrCreateSlot(remotePeerId);
    slot.channel = channel;
    channel.onmessage = (event) => this.handleDataMessage(event.data);
    channel.onopen = () => {
      slot.retryCount = 0;
      this.broadcast('sync_request', { sessionId: this.options.sessionId });
    };
  }

  private handleDataMessage(data: unknown) {
    if (typeof data !== 'string') return;
    try {
      const message = JSON.parse(data) as SessionPeerMessage;
      if (!message.id || this.seen.has(message.id)) return;
      this.markSeen(message.id);
      this.options.onMessage?.(message);
    } catch {
      // Ignore malformed peer messages. Supabase Realtime remains the fallback.
    }
  }

  private async handleSignal(signal: SignalMessage) {
    if (this.closed || signal.senderPeerId === this.options.peerId) return;
    const slot = this.getOrCreateSlot(signal.senderPeerId);

    if (signal.kind === 'offer') {
      await slot.connection.setRemoteDescription(signal.payload as RTCSessionDescriptionInit);
      const answer = await slot.connection.createAnswer();
      await slot.connection.setLocalDescription(answer);
      await this.sendSignal(signal.senderPeerId, 'answer', answer);
      return;
    }

    if (signal.kind === 'answer') {
      await slot.connection.setRemoteDescription(signal.payload as RTCSessionDescriptionInit);
      return;
    }

    await slot.connection.addIceCandidate(signal.payload as RTCIceCandidateInit);
  }

  private retry(remotePeerId: string) {
    const slot = this.peers.get(remotePeerId);
    if (!slot || slot.retryCount >= 3 || this.closed) return;
    slot.retryCount += 1;
    const delay = this.options.retryDelayMs ?? 750;
    window.setTimeout(() => {
      if (!this.closed) void this.connectToPeer(remotePeerId);
    }, delay * slot.retryCount);
  }

  private async sendSignal(
    targetPeerId: string,
    kind: SignalMessage['kind'],
    payload: SignalMessage['payload'],
  ) {
    await this.options.signaling.sendSignal({
      id: crypto.randomUUID(),
      sessionId: this.options.sessionId,
      senderPeerId: this.options.peerId,
      targetPeerId,
      kind,
      payload,
      createdAt: new Date().toISOString(),
    });
  }

  private markSeen(id: string) {
    this.seen.add(id);
    if (this.seen.size > 500) {
      const first = this.seen.values().next().value as string | undefined;
      if (first) this.seen.delete(first);
    }
  }

  private defaultIceServers(): RTCIceServer[] {
    const servers: RTCIceServer[] = [{ urls: 'stun:stun.l.google.com:19302' }];
    if (shouldUseTurnFallback({
      explicitFallbackRequested: this.options.explicitTurnFallbackRequested ?? false,
      usedTurnMinutes: this.options.usedTurnMinutes ?? 0,
      policy: DEFAULT_MVP_SESSION_POLICY,
    })) {
      return servers;
    }
    return servers;
  }
}
