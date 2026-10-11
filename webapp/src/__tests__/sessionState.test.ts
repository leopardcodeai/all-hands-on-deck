import { describe, it, expect } from 'vitest';
import { applyEvent, initialState, type SessionState } from '../sessionState';
import type { PhotoSessionDTO, WireEvent } from '../wire';

const baseSession: PhotoSessionDTO = {
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
};

describe('applyEvent', () => {
  it('captures session metadata without mutating the input state', () => {
    const before: SessionState = { ...initialState };
    const after = applyEvent(before, { sessionMetadata: baseSession });
    expect(after.metadata?.id).toBe('ABCDEF1234');
    expect(before.metadata).toBeUndefined();
  });

  it('countdownStarted parses ISO timestamps and stores duration', () => {
    const photoAt = '2026-04-27T10:05:00.000Z';
    const after = applyEvent(initialState, {
      countdownStarted: { photoAt, duration: 7, startedBy: 'host' },
    });
    expect(after.countdownTargetMs).toBe(Date.parse(photoAt));
    expect(after.countdownDuration).toBe(7);
  });

  it('countdownStarted with garbage timestamp falls back to undefined target', () => {
    const after = applyEvent(initialState, {
      countdownStarted: { photoAt: 'not-a-date', duration: 7, startedBy: 'host' },
    });
    expect(after.countdownTargetMs).toBeUndefined();
    expect(after.countdownDuration).toBe(7);
  });

  it('countdownCancelled clears both fields', () => {
    const mid = applyEvent(initialState, {
      countdownStarted: { photoAt: '2026-04-27T10:05:00.000Z', duration: 7, startedBy: 'host' },
    });
    const after = applyEvent(mid, { countdownCancelled: { by: 'host' } });
    expect(after.countdownTargetMs).toBeUndefined();
    expect(after.countdownDuration).toBeUndefined();
  });

  it('photoCaptured clears the active countdown', () => {
    const mid = applyEvent(initialState, {
      countdownStarted: { photoAt: '2026-04-27T10:05:00.000Z', duration: 7, startedBy: 'host' },
    });
    const after = applyEvent(mid, { photoCaptured: { at: '2026-04-27T10:05:00.000Z' } });
    expect(after.countdownTargetMs).toBeUndefined();
    expect(after.countdownDuration).toBeUndefined();
  });

  it('finalPhotoAvailable stores the base64 payload (caller turns it into a blob)', () => {
    const after = applyEvent(initialState, {
      finalPhotoAvailable: { photoID: 'p1', jpeg: 'AAAA' },
    });
    expect(after.finalPhotoBase64).toBe('AAAA');
  });

  it('sessionEnded transitions status to ended', () => {
    const connected: SessionState = { ...initialState, status: 'connected' };
    const after = applyEvent(connected, { sessionEnded: {} });
    expect(after.status).toBe('ended');
  });

  it('previewFrame leaves session state untouched (frames flow on a separate channel)', () => {
    const before: SessionState = { ...initialState, status: 'connected', metadata: baseSession };
    const after = applyEvent(before, {
      previewFrame: { jpeg: 'AAAA', capturedAt: '2026-04-27T10:00:00.000Z' },
    });
    expect(after).toEqual(before);
  });

  it('participantJoined / Left / readyChanged / reactionSent leave state untouched', () => {
    const events: WireEvent[] = [
      {
        participantJoined: {
          id: 'v1', displayName: 'Mate', role: 'viewer',
          joinedAt: '2026-04-27T10:00:00.000Z', isReady: false, connectionType: 'web',
        },
      },
      { participantLeft: { participantID: 'v1' } },
      { participantReadyChanged: { participantID: 'v1', isReady: true } },
      { reactionSent: { by: 'v1', reaction: 'ready' } },
      { captureRequested: { by: 'v1' } },
      { captureApproved: { approvedBy: 'h' } },
      { captureDenied: { deniedBy: 'h' } },
    ];
    for (const e of events) {
      expect(applyEvent(initialState, e)).toEqual(initialState);
    }
  });
});
