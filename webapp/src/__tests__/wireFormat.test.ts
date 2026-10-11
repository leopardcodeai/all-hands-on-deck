import { describe, it, expect } from 'vitest';
import type { WireEnvelope } from '../wire';
import { applyEvent, initialState } from '../sessionState';

/**
 * Golden tests: synthetic envelopes shaped exactly as the iOS host emits them.
 * Catches drift in the wire contract before the iOS↔web handshake breaks in
 * production.
 *
 * Swift `enum SessionEvent` with associated values JSON-encodes as a single-key
 * object — so `{ "countdownStarted": { ... } }` is the canonical shape.
 */
describe('iOS wire format compatibility', () => {
  it('decodes a sessionMetadata envelope and applies it', () => {
    const env: WireEnvelope = {
      sessionId: 'ABCDEF1234',
      senderId: 'host-id',
      createdAt: '2026-04-27T10:00:00.000Z',
      event: {
        sessionMetadata: {
          id: 'ABCDEF1234',
          hostName: 'Captain',
          createdAt: '2026-04-27T10:00:00.000Z',
          expiresAt: '2026-04-27T10:30:00.000Z',
          timerDuration: 10,
          triggerPermission: 'hostOnly',
          isDiscoverableNearby: true,
          allowWebJoin: true,
          allowFinalPhotoDownload: true,
          participants: [],
        },
      },
    };
    const next = applyEvent(initialState, env.event);
    expect(next.metadata?.hostName).toBe('Captain');
  });

  it('decodes a countdownStarted envelope', () => {
    const env: WireEnvelope = {
      sessionId: 'X', senderId: 'host', createdAt: '2026-04-27T10:00:00.000Z',
      event: {
        countdownStarted: {
          photoAt: '2026-04-27T10:00:10.000Z',
          duration: 10,
          startedBy: 'host',
        },
      },
    };
    const next = applyEvent(initialState, env.event);
    expect(next.countdownDuration).toBe(10);
    expect(next.countdownTargetMs).toBe(Date.parse('2026-04-27T10:00:10.000Z'));
  });

  it('decodes a sessionEnded envelope (empty object form)', () => {
    const env: WireEnvelope = {
      sessionId: 'X', senderId: 'server', createdAt: '2026-04-27T10:00:00.000Z',
      event: { sessionEnded: {} },
    };
    const next = applyEvent({ ...initialState, status: 'connected' }, env.event);
    expect(next.status).toBe('ended');
  });

  it('rejects envelopes whose event has zero recognized keys (returns input state)', () => {
    // Simulates a future iOS event the web client doesn't yet understand.
    const unknown = { somethingNew: { x: 1 } } as unknown as WireEnvelope['event'];
    const next = applyEvent(initialState, unknown);
    expect(next).toEqual(initialState);
  });
});
