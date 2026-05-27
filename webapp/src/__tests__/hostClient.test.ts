import { describe, expect, it, vi, beforeEach } from 'vitest';
import { CaptainClient, type CaptainState } from '../CaptainClient';

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
        insert: () => Promise.resolve(),
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
});
