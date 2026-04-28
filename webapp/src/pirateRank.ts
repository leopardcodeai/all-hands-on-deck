const RANKS = [
  { emoji: '🪣', title: 'Cabin Boy' },
  { emoji: '⛵', title: 'Deckhand' },
  { emoji: '🪢', title: 'Boatswain' },
  { emoji: '💣', title: 'Gunner' },
  { emoji: '🧭', title: 'Navigator' },
  { emoji: '⚖️', title: 'Quartermaster' },
  { emoji: '⚓', title: 'First Mate' },
  { emoji: '🏴‍☠️', title: 'Captain' },
] as const;

const KEY = 'pirateRank';

/** Returns a random rank, persisted for the browser session. */
export function getOrAssignRank(): string {
  const stored = sessionStorage.getItem(KEY);
  if (stored) return stored;
  const rank = RANKS[Math.floor(Math.random() * RANKS.length)];
  const name = `${rank.emoji} ${rank.title}`;
  sessionStorage.setItem(KEY, name);
  return name;
}
