import { useState } from 'react';

/**
 * Mirrors `Reaction.swift` on iOS — keep the rawValue strings in sync.
 * Sending a string the iOS host doesn't recognize is harmless (the iOS
 * `Reaction(rawValue:)` returns nil and the toast is skipped).
 */
const REACTIONS: { id: string; label: string; symbol: string }[] = [
  { id: 'ready',        label: 'Ready',        symbol: '✓' },
  { id: 'waitMoment',   label: 'Wait a sec',   symbol: '⌛' },
  { id: 'again',        label: 'Again',        symbol: '↻' },
  { id: 'cantSeeMe',    label: "Can't see me", symbol: '⊘' },
  { id: 'raiseCamera',  label: 'Camera up',    symbol: '↑' },
  { id: 'moveLeft',     label: 'Move left',    symbol: '←' },
  { id: 'moveRight',    label: 'Move right',   symbol: '→' }
];

export function ReactionStrip({ onReact }: { onReact: (id: string) => void }) {
  const [active, setActive] = useState<string | null>(null);
  return (
    <div className="reaction-strip">
      {REACTIONS.map(r => (
        <button
          key={r.id}
          className={`reaction-chip ${active === r.id ? 'on' : ''}`}
          onClick={() => {
            onReact(r.id);
            setActive(r.id);
            setTimeout(() => setActive(c => c === r.id ? null : c), 1200);
          }}
        >
          <span className="reaction-symbol">{r.symbol}</span>
          <span>{r.label}</span>
        </button>
      ))}
    </div>
  );
}
