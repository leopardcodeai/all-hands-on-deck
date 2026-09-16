import { afterEach, expect, it, vi } from 'vitest';
import { CaptainClient } from '../CaptainClient';
import { startCamera } from '../CameraCapture';
const mocks = vi.hoisted(() => ({ create: vi.fn(), subscribe: vi.fn(), insert: vi.fn() }));
vi.mock('../lib/logger', () => ({ logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() } }));
vi.mock('../lib/supabase', () => ({ getSupabaseClient: () => ({ from: () => ({ insert: mocks.insert }) }) }));
vi.mock('../services/sessionService', () => ({ createSession: mocks.create }));
vi.mock('../services/realtimeService', () => ({ subscribeToSessionRealtime: mocks.subscribe }));
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.clearAllMocks(); });
it('does not subscribe when session creation completes after stop', async () => {
  let resolve!: (value: unknown) => void;
  mocks.create.mockReturnValue(new Promise(r => { resolve = r; }));
  const client = new CaptainClient();
  const pending = client.startSession('Captain');
  client.stop();
  resolve({ session: { id: 'id', code: 'ABC123' }, participant: { id: 'p' } });
  await pending;
  expect(mocks.subscribe).not.toHaveBeenCalled();
  expect(mocks.insert).not.toHaveBeenCalled();
});
it('releases camera tracks if video playback fails during initialization', async () => {
  const stop = vi.fn();
  vi.stubGlobal('navigator', { mediaDevices: { getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [{ stop }] }) } });
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockRejectedValue(new Error('playback failed'));
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {});
  await expect(startCamera()).rejects.toThrow('playback failed');
  expect(stop).toHaveBeenCalledOnce();
});
