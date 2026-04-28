/**
 * Pure room/routing logic — no WebSocket or HTTP dependencies, so it can be
 * unit-tested in isolation. `index.ts` glues these primitives onto a real
 * `WebSocketServer`.
 */

export type Role = 'host' | 'viewer';

/** Anything `index.ts` needs from a WebSocket — narrowed for testability. */
export interface SocketLike {
  send(payload: string | Buffer): void;
  readyState: number;
}

export interface Member<Sock extends SocketLike = SocketLike> {
  ws: Sock;
  role: Role;
  participantId: string;
  joinedAt: number;
}

export interface Room<Sock extends SocketLike = SocketLike> {
  sessionId: string;
  members: Set<Member<Sock>>;
  lastActivity: number;
}

export const OPEN = 1; // mirrors `WebSocket.OPEN`

export class RoomRegistry<Sock extends SocketLike = SocketLike> {
  private readonly rooms = new Map<string, Room<Sock>>();

  /** Number of live rooms — exposed for /health. */
  get size(): number { return this.rooms.size; }

  getOrCreate(sessionId: string, now: number = Date.now()): Room<Sock> {
    let r = this.rooms.get(sessionId);
    if (!r) {
      r = { sessionId, members: new Set(), lastActivity: now };
      this.rooms.set(sessionId, r);
    }
    return r;
  }

  /** Returns the host of a room, if any. */
  host(room: Room<Sock>): Member<Sock> | undefined {
    for (const m of room.members) if (m.role === 'host') return m;
    return undefined;
  }

  /**
   * Routing rule:
   *  - host  → broadcast to every other open member
   *  - viewer → forward to the host only (control events)
   * Returns the count of recipients that actually received the payload.
   */
  route(room: Room<Sock>, sender: Member<Sock>, payload: string | Buffer): number {
    let delivered = 0;
    if (sender.role === 'host') {
      for (const m of room.members) {
        if (m === sender) continue;
        if (m.ws.readyState === OPEN) { m.ws.send(payload); delivered++; }
      }
    } else {
      const h = this.host(room);
      if (h && h.ws.readyState === OPEN) { h.ws.send(payload); delivered++; }
    }
    return delivered;
  }

  /** Broadcast to everyone in `room`, optionally skipping `except`. */
  broadcast(room: Room<Sock>, payload: string | Buffer, except?: Member<Sock>): void {
    for (const m of room.members) {
      if (m === except) continue;
      if (m.ws.readyState === OPEN) m.ws.send(payload);
    }
  }

  /**
   * Removes the room and returns it. Used after a host disconnect to deliver
   * sessionEnded to the remaining viewers and then drop the room.
   */
  delete(sessionId: string): Room<Sock> | undefined {
    const r = this.rooms.get(sessionId);
    if (r) this.rooms.delete(sessionId);
    return r;
  }

  /** Removes a member; returns whether the room is now empty. */
  removeMember(room: Room<Sock>, member: Member<Sock>): boolean {
    room.members.delete(member);
    if (room.members.size === 0) {
      this.rooms.delete(room.sessionId);
      return true;
    }
    return false;
  }

  /** Drops every empty room idle for longer than `ttlMs`. */
  reap(ttlMs: number, now: number = Date.now()): number {
    let dropped = 0;
    for (const [id, room] of this.rooms) {
      if (now - room.lastActivity > ttlMs && room.members.size === 0) {
        this.rooms.delete(id);
        dropped++;
      }
    }
    return dropped;
  }

  /** Test helper. */
  has(sessionId: string): boolean { return this.rooms.has(sessionId); }
}

/** Validates upgrade query params. Used by `index.ts`; tested separately. */
export interface JoinParams { sessionId: string; role: Role; participantId: string; }

export function parseJoinParams(query: URLSearchParams): JoinParams | null {
  const sessionId = query.get('session');
  const role = query.get('role');
  const participantId = query.get('pid');
  if (!sessionId || !participantId) return null;
  if (role !== 'host' && role !== 'viewer') return null;
  return { sessionId, role, participantId };
}
