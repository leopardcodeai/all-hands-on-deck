import { describe, expect, it, vi } from 'vitest';
import { createSessionCode, makePhotoStoragePath, normalizeSessionCode } from '../services/sessionService';
import { EventDeduper } from '../services/realtimeService';

describe('Supabase service helpers', () => {
  it('generates eight character human-readable session codes', () => {
    const code = createSessionCode(() => 0);

    expect(code).toBe('AAAAAAAA');
    expect(createSessionCode()).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
  });

  it('normalizes user-entered session codes', () => {
    expect(normalizeSessionCode(' ab-c 12 ')).toBe('ABC12');
  });

  it('builds the required Supabase Storage path', () => {
    const randomUUID = vi.spyOn(crypto, 'randomUUID').mockReturnValue('photo-id' as `${string}-${string}-${string}-${string}-${string}`);

    expect(makePhotoStoragePath('session-id', new File(['x'], 'crew photo.jpg', { type: 'image/jpeg' })))
      .toBe('sessions/session-id/photo-id-crew-photo.jpg');

    randomUUID.mockRestore();
  });

  it('deduplicates realtime events by database id or client id', () => {
    const deduper = new EventDeduper();

    expect(deduper.seen({ id: 'db-1', client_generated_id: null })).toBe(false);
    expect(deduper.seen({ id: 'db-1', client_generated_id: null })).toBe(true);
    expect(deduper.seen({ id: 'db-2', client_generated_id: 'client-1' })).toBe(false);
    expect(deduper.seen({ id: 'db-3', client_generated_id: 'client-1' })).toBe(true);
  });
});
