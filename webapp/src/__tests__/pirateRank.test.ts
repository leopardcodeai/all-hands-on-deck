import { describe, it, expect, vi, afterEach } from 'vitest';
import { getOrAssignRank } from '../pirateRank';

describe('getOrAssignRank', () => {
  afterEach(() => vi.restoreAllMocks());

  it('returns one of the seven canonical ranks', () => {
    const valid = ['Cabin Boy', 'Deckhand', 'Boatswain', 'Gunner', 'Navigator', 'Quartermaster', 'First Mate', 'Captain'];
    const rank = getOrAssignRank();
    const title = rank.split(' ').slice(1).join(' ');
    expect(valid).toContain(title);
  });

  it('persists the same rank across calls within a session', () => {
    vi.spyOn(Math, 'random').mockReturnValue(0); // → first rank
    const a = getOrAssignRank();
    vi.spyOn(Math, 'random').mockReturnValue(0.99); // would pick a different rank if uncached
    const b = getOrAssignRank();
    expect(b).toBe(a);
  });

  it('writes the assigned rank into sessionStorage', () => {
    const rank = getOrAssignRank();
    expect(sessionStorage.getItem('pirateRank')).toBe(rank);
  });

  it('honors a pre-existing sessionStorage value over a new draw', () => {
    sessionStorage.setItem('pirateRank', '🏴‍☠️ Captain');
    expect(getOrAssignRank()).toBe('🏴‍☠️ Captain');
  });

  it('produces an emoji-prefixed string', () => {
    const rank = getOrAssignRank();
    // First codepoint should be non-ASCII (an emoji).
    const firstCode = rank.codePointAt(0)!;
    expect(firstCode).toBeGreaterThan(0x7f);
  });
});
