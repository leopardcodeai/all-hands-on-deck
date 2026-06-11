import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { CaptainClient, type CaptainState } from '../CaptainClient';

const { insertSpy } = vi.hoisted(() => ({
  // Catches every table insert (session_events AND logger rows), so tests
  // filter by the session_events row shape via insertedEventTypes().
  insertSpy: vi.fn((_row?: unknown) => Promise.resolve({ error: null })),
}));

function insertedEventTypes(): string[] {
  return insertSpy.mock.calls
    .map(([row]) => row as { type?: string; payload?: unknown })
    .filter(row => typeof row?.type === 'string' && 'payload' in row)
    .map(row => row.type as string);
}

vi.mock('../lib/supabase', () => ({
  getSupabaseClient: () => {
    let subCb: ((status: string, err?: Error) => void) | undefined;
    const channel = {
      on: () => channel,
      subscribe: (cb?: (status: string, err?: Error) => void) => { subCb = cb; cb?.('SUBSCRIBED', undefined); },
      removeChannel: () => Promise.resolve(),
    };
    return {
      from: () => ({
        insert: insertSpy,
        select: () => Promise.resolve({ data: [], error: null }),
        eq: () => ({ data: [], error: null }),
        order: () => Promise.resolve({ data: [], error: null }),
      }),
      channel: () => channel,
      removeChannel: () => Promise.resolve(),
    };
  },
  isSupabaseConfigured: () => true,
  supabaseConfig: { url: 'https://test.supabase.co', anonKey: 'test-key' },
}));

vi.mock('../services/sessionService', () => ({
  createSession: vi.fn().mockResolvedValue({
    session: { id: 'uuid-123', code: 'ABC123', status: 'active', created_at: new Date().toISOString(), expires_at: null, metadata: {} },
    participant: { id: 'participant-1' },
  }),
}));

describe('CaptainClient', () => {
  let client: CaptainClient;

  beforeEach(() => {
    client = new CaptainClient();
    insertSpy.mockClear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('starts in idle state', () => {
    const state = client.getState();
    expect(state.status).toBe('idle');
    expect(state.sessionCode).toBe('');
    expect(state.sessionId).toBe('');
    expect(state.participants).toEqual([]);
    expect(state.finalPhotoBase64).toBeNull();
  });

  it('creates a session and transitions to active', async () => {
    const states: CaptainState[] = [];
    client.subscribe(s => states.push(s));

    await client.startSession('Captain');

    expect(states.length).toBeGreaterThanOrEqual(2);
    const activeState = states[states.length - 1];
    expect(activeState.status).toBe('active');
    expect(activeState.sessionCode).toBe('ABC123');
    expect(activeState.sessionId).toBe('uuid-123');
  });

  it('sets finalPhotoBase64 after sendFinalPhoto', async () => {
    await client.startSession('Captain');

    const jpeg = '/9j/4AAQSkZJRgABAQAAAQABAAD';
    await client.sendFinalPhoto(jpeg);

    const state = client.getState();
    expect(state.finalPhotoBase64).toBe(jpeg);
  });

  it('clears finalPhotoBase64 after clearFinalPhoto', async () => {
    await client.startSession('Captain');
    await client.sendFinalPhoto('/9j/4AAQ');
    expect(client.getState().finalPhotoBase64).toBe('/9j/4AAQ');

    client.clearFinalPhoto();
    expect(client.getState().finalPhotoBase64).toBeNull();
  });

  it('notifies listeners on state changes', async () => {
    const listener = vi.fn();
    const unsub = client.subscribe(listener);

    await client.startSession('Captain');
    expect(listener).toHaveBeenCalled();

    client.clearFinalPhoto();
    expect(listener).toHaveBeenCalledTimes(3);

    unsub();
  });

  it('ignores empty preview frames', async () => {
    await client.startSession('Captain');
    const before = client.getState();
    await client.sendPreviewFrame('');
    const after = client.getState();
    // sendPreviewFrame with empty string should not change state or throw
    expect(after.sessionCode).toBe(before.sessionCode);
  });

  it('stops without errors', async () => {
    await client.startSession('Captain');
    client.stop();
    expect(true).toBe(true);
  });

  describe('preview frame broadcast', () => {
    it('sends preview frames via REST broadcast instead of session_events inserts', async () => {
      const fetchSpy = vi.fn().mockResolvedValue({ ok: true, status: 202 });
      vi.stubGlobal('fetch', fetchSpy);

      await client.startSession('Captain');
      insertSpy.mockClear();

      await client.sendPreviewFrame('/9j/4AAQSkZJRg');

      expect(insertedEventTypes()).toHaveLength(0);
      expect(fetchSpy).toHaveBeenCalledTimes(1);

      const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
      expect(url).toBe('https://test.supabase.co/realtime/v1/api/broadcast');
      expect(init.method).toBe('POST');
      expect(init.headers).toMatchObject({
        apikey: 'test-key',
        Authorization: 'Bearer test-key',
        'Content-Type': 'application/json',
      });

      const body = JSON.parse(init.body as string) as {
        messages: Array<{ topic: string; event: string; payload: { jpeg: string; capturedAt: string; senderId: string } }>;
      };
      expect(body.messages).toHaveLength(1);
      expect(body.messages[0].topic).toBe('session-frames:uuid-123');
      expect(body.messages[0].event).toBe('preview_frame');
      expect(body.messages[0].payload.jpeg).toBe('/9j/4AAQSkZJRg');
      expect(body.messages[0].payload.senderId).toBe(client.participantId);
      expect(body.messages[0].payload.capturedAt).toBeTruthy();
    });

    it('strips a data: URL prefix from the broadcast jpeg payload', async () => {
      const fetchSpy = vi.fn().mockResolvedValue({ ok: true, status: 202 });
      vi.stubGlobal('fetch', fetchSpy);

      await client.startSession('Captain');
      await client.sendPreviewFrame('data:image/jpeg;base64,/9j/4AAQ');

      const body = JSON.parse((fetchSpy.mock.calls[0] as [string, RequestInit])[1].body as string) as {
        messages: Array<{ payload: { jpeg: string } }>;
      };
      expect(body.messages[0].payload.jpeg).toBe('/9j/4AAQ');
    });

    it('does not broadcast before a session exists', async () => {
      const fetchSpy = vi.fn().mockResolvedValue({ ok: true, status: 202 });
      vi.stubGlobal('fetch', fetchSpy);

      await client.sendPreviewFrame('/9j/4AAQ');

      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('swallows broadcast network errors without throwing', async () => {
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));

      await client.startSession('Captain');
      await expect(client.sendPreviewFrame('/9j/4AAQ')).resolves.toBeUndefined();
    });

    it('still sends non-frame events through session_events', async () => {
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 202 }));

      await client.startSession('Captain');
      insertSpy.mockClear();

      await client.sendFinalPhoto('/9j/4AAQ');
      expect(insertedEventTypes()).toEqual(['finalPhotoAvailable']);
    });
  });
});
