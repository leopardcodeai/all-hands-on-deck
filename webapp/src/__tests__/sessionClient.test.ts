import { describe, expect, it, vi } from 'vitest';
import { SessionClient } from '../SessionClient';
import type { WireEvent } from '../wire';

describe('SessionClient', () => {
  it('deduplicates repeated participant rows by stable anonymous identity', () => {
    const client = new SessionClient('ROOM123', 'Deckhand');
    const applyBootstrap = (client as unknown as {
      applyBootstrap: (bootstrap: unknown) => void;
    }).applyBootstrap.bind(client);

    applyBootstrap({
      session: {
        id: 'session-row-id',
        code: 'ROOM123',
        created_at: '2026-05-05T12:00:00.000Z',
        expires_at: null,
        metadata: {},
      },
      participant: {},
      participants: [
        {
          id: 'first-row',
          anonymous_id: 'same-browser-viewer',
          display_name: 'Viewer',
          role: 'viewer',
          joined_at: '2026-05-05T12:00:00.000Z',
        },
        {
          id: 'second-row',
          anonymous_id: 'same-browser-viewer',
          display_name: 'Viewer',
          role: 'viewer',
          joined_at: '2026-05-05T12:00:01.000Z',
        },
      ],
      photos: [],
    });

    expect(client.metadata?.participants).toHaveLength(1);
    expect(client.metadata?.participants[0]?.id).toBe('same-browser-viewer');
  });

  it('clears the visible final photo URL when a new countdown starts', () => {
    const createObjectURL = vi
      .spyOn(URL, 'createObjectURL')
      .mockReturnValueOnce('blob:first-photo');
    const revokeObjectURL = vi
      .spyOn(URL, 'revokeObjectURL')
      .mockImplementation(() => {});

    const client = new SessionClient('ROOM123', 'Deckhand');
    const handleEvent = (client as unknown as {
      handleEvent: (event: WireEvent) => void;
    }).handleEvent.bind(client);

    handleEvent({ finalPhotoAvailable: { photoID: 'p1', jpeg: 'AAAA' } });
    expect(client.finalPhotoURL).toBe('blob:first-photo');

    handleEvent({
      countdownStarted: {
        photoAt: '2026-05-05T12:00:00.000Z',
        duration: 5,
        startedBy: 'host',
      },
    });

    expect(client.finalPhotoURL).toBeUndefined();
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:first-photo');

    createObjectURL.mockRestore();
    revokeObjectURL.mockRestore();
  });
});
