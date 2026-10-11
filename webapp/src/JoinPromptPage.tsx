import { useRef, useState, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { DesignLabels } from './DesignLabels';

const PIRATE_NAMES = [
  '🪣 Cabin Boy Joe',
  '⛵ Deckhand Mia',
  '🪢 Boatswain Kai',
  '⚓ First Mate Lia',
  '🏴‍☠️ Captain Alex',
  '💣 Gunner Rex',
  '🧭 Navigator Sam',
  '⚖️ Quartermaster Pat',
];

function usePirateName() {
  const [idx, setIdx] = useState(() => Math.floor(Math.random() * PIRATE_NAMES.length));
  const roll = useCallback(() => setIdx((i) => (i + 1) % PIRATE_NAMES.length), []);
  return { name: PIRATE_NAMES[idx], roll };
}

function CodeInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);

  const handleChange = (i: number, char: string) => {
    const next = value.split('');
    next[i] = char.toUpperCase();
    const joined = next.join('');
    onChange(joined);
    if (char && i < 5) {
      refs.current[i + 1]?.focus();
    }
  };

  const handleKeyDown = (i: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !value[i] && i > 0) {
      refs.current[i - 1]?.focus();
      const next = value.split('');
      next[i - 1] = '';
      onChange(next.join(''));
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 6);
    onChange(pasted.padEnd(6, ''));
    const focusIdx = Math.min(pasted.length, 5);
    refs.current[focusIdx]?.focus();
  };

  return (
    <div className="code-input-group" onPaste={handlePaste}>
      {Array.from({ length: 6 }).map((_, i) => (
        <input
          key={i}
          ref={(el) => { refs.current[i] = el; }}
          type="text"
          inputMode="text"
          maxLength={1}
          value={value[i] || ''}
          onChange={(e) => handleChange(i, e.target.value)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          className={`code-input-box ${value[i] ? 'filled' : ''}`}
          aria-label={`Character ${i + 1}`}
        />
      ))}
    </div>
  );
}

export function JoinPromptPage() {
  const navigate = useNavigate();
  const [code, setCode] = useState('');
  const { name, roll } = usePirateName();

  useEffect(() => {
    if (code.length === 6) {
      navigate(`/join/${code}`);
    }
  }, [code, navigate]);

  return (
    <div className="center-stack join-prompt-page">
      <div className="join-card">
        <span className="join-skull">☠</span>
        <h1 className="join-title">HOIST THE FLAG</h1>
        <p className="join-subtitle">
          Enter the session code or scan the Captain&apos;s QR
        </p>

        <CodeInput value={code} onChange={setCode} />

        <div className="join-divider">
          <span>OR</span>
        </div>

        <button className="btn-secondary btn-full" onClick={() => {}}>
          📷 Scan QR with camera
        </button>

        <div className="join-name-section">
          <span className="join-name-label">Your pirate name</span>
          <div className="join-name-row">
            <span className="join-name-display">{name}</span>
            <button className="icon-button icon-sm" onClick={roll} aria-label="Reroll name" title="Roll again">
              ↻
            </button>
          </div>
        </div>

        <button
          className="btn-primary btn-full"
          disabled={code.length < 6}
          onClick={() => navigate(`/join/${code}`)}
          style={{ opacity: code.length < 6 ? 0.4 : 1 }}
        >
          BOARD THE SHIP →
        </button>
      </div>

      <p className="muted-note" style={{ marginTop: 16 }}>
        <a href="/privacy" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.privacy}</a>
        {' · '}
        <a href="/imprint" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.imprint}</a>
      </p>
    </div>
  );
}
