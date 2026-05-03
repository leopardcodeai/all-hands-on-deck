import { useState } from 'react';
import { DesignLabels } from './DesignLabels';

/**
 * Mirrors `Reaction.swift` on iOS — keep the rawValue strings in sync.
 * Labels come from DesignLabels (same source as iOS).
 */
const REACTIONS: { id: string; label: string; symbol: string }[] = [
  { id: 'ready',        label: DesignLabels.reactionReady,        symbol: '✓' },
  { id: 'waitMoment',   label: DesignLabels.reactionWait,         symbol: '⌛' },
  { id: 'again',        label: DesignLabels.reactionAgain,        symbol: '↻' },
  { id: 'cantSeeMe',    label: DesignLabels.reactionCantSeeMe,    symbol: '⊘' },
  { id: 'raiseCamera',  label: DesignLabels.reactionRaiseCamera,  symbol: '↑' },
  { id: 'moveLeft',     label: DesignLabels.reactionMoveLeft,     symbol: '←' },
  { id: 'moveRight',    label: DesignLabels.reactionMoveRight,    symbol: '→' }
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
