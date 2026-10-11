import { beforeEach, describe, expect, it, vi } from 'vitest';
import { SessionClient } from '../SessionClient';
import type { WireEvent } from '../wire';

interface MockBroadcastChannel {
  topic: string;
  options: unknown;
  handlers: Array<{ event: string; callback: (message: { payload: unknown }) => void }>;
  on: (type: string, filter: { event: string }, callback: (message: { payload: unknown }) => void) => MockBroadcastChannel;
  subscribe: () => MockBroadcastChannel;
}

const harness = vi.hoisted(() => ({
  channels: [] as Array<{ topic: string; options: unknown; handlers: Array<{ event: string; callback: (message: { payload: unknown }) => void }> }>,
  removedChannels: [] as unknown[],
}));

vi.mock('../lib/supabase', () => ({
  getSupabaseClient: () => ({
    channel: (topic: string, options?: unknown) => {
      const channel: MockBroadcastChannel = {
        topic,
        options,
        handlers: [],
        on(_type, filter, callback) {
          channel.handlers.push({ event: filter.event, callback });
          return channel;
        },
        subscribe() { return channel; },
      };
      harness.channels.push(channel);
      return channel;
    },
    removeChannel: (channel: unknown) => {
      harness.removedChannels.push(channel);
      return Promise.resolve('ok');
    },
    from: () => ({
      insert: () => Promise.resolve({ error: null }),
    }),
  }),
  isSupabaseConfigured: () => true,
  supabaseConfig: { url: 'https://test.supabase.co', anonKey: 'test-key' },
}));

vi.mock('../services/sessionService', () => ({
  joinSession: vi.fn().mockResolvedValue({
    session: {
      id: 'session-uuid-1',
      code: 'ROOM123',
      created_at: '2026-06-11T12:00:00.000Z',
      expires_at: null,
      metadata: {},
    },
    participant: { id: 'participant-row-1' },
    participants: [],
    photos: [],
  }),
}));

vi.mock('../services/realtimeService', () => ({
  subscribeToSessionRealtime: vi.fn(() => ({ unsubscribe: vi.fn().mockResolvedValue(undefined) })),
}));

describe('SessionClient', () => {
  beforeEach(() => {
    harness.channels.length = 0;
    harness.removedChannels.length = 0;
  });
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

  describe('preview frame broadcast', () => {
    it('subscribes to the session frame broadcast channel on connect and removes it on disconnect', async () => {
      const client = new SessionClient('ROOM123', 'Deckhand');
      await client.connect();

      const frameChannel = harness.channels.find(c => c.topic === 'session-frames:session-uuid-1');
      expect(frameChannel).toBeDefined();
      expect(frameChannel?.options).toEqual({ config: { broadcast: { self: false } } });
      expect(frameChannel?.handlers.map(h => h.event)).toContain('preview_frame');

      client.disconnect();
      expect(harness.removedChannels).toContain(frameChannel);
    });

    it('applies broadcast frames from other senders', async () => {
      const createObjectURL = vi.spyOn(URL, 'createObjectURL').mockReturnValueOnce('blob:broadcast-frame');
      const revokeObjectURL = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});

      const client = new SessionClient('ROOM123', 'Deckhand');
      await client.connect();
      const frames: string[] = [];
      client.subscribeFrame(url => frames.push(url));

      const handler = harness.channels
        .find(c => c.topic === 'session-frames:session-uuid-1')
        ?.handlers.find(h => h.event === 'preview_frame');
      handler?.callback({
        payload: { jpeg: 'AAAA', capturedAt: '2026-06-11T12:00:01.000Z', senderId: 'ios-host-1' },
      });

      expect(client.latestFrameURL).toBe('blob:broadcast-frame');
      expect(frames).toEqual(['blob:broadcast-frame']);

      createObjectURL.mockRestore();
      revokeObjectURL.mockRestore();
    });

    it('ignores broadcast frames from its own senderId and malformed payloads', () => {
      const createObjectURL = vi.spyOn(URL, 'createObjectURL');

      const client = new SessionClient('ROOM123', 'Deckhand');
      const handleBroadcastFrame = (client as unknown as {
        handleBroadcastFrame: (payload: unknown) => void;
      }).handleBroadcastFrame.bind(client);

      handleBroadcastFrame({ jpeg: 'AAAA', capturedAt: '2026-06-11T12:00:01.000Z', senderId: client.participantId });
      handleBroadcastFrame({ capturedAt: '2026-06-11T12:00:01.000Z', senderId: 'ios-host-1' });
      handleBroadcastFrame(null);

      expect(createObjectURL).not.toHaveBeenCalled();
      expect(client.latestFrameURL).toBeUndefined();

      createObjectURL.mockRestore();
    });
  });
});
