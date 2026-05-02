import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

export function HomePage() {
  const navigate = useNavigate();
  const [code, setCode] = useState('');

  return (
    <div className="center-stack">
      <span className="pill pill-gold">⚓︎ by Captain Leopard</span>
      <h1 className="title">All Hands On Deck</h1>
      <p className="subtitle">
        Web viewer for Captain&apos;s live crew photo session.<br/>
        Enter the code below or scan the Captain&apos;s QR code.
      </p>
      <input
        className="id-input"
        placeholder="ABCDEF1234"
        value={code}
        onChange={e => setCode(e.target.value.toUpperCase())}
        autoCapitalize="characters"
        autoCorrect="off"
        autoComplete="off"
        spellCheck={false}
      />
      <button
        className="btn-primary"
        disabled={code.length < 6}
        onClick={() => navigate(`/join/${code}`)}
        style={{ opacity: code.length < 6 ? 0.5 : 1 }}
      >
        Join →
      </button>
      <p className="muted-note">
        No install. No sign-in.
      </p>
      <p className="muted-note" style={{ marginTop: 24, fontSize: 11 }}>
        <a href="/privacy" style={{ color: 'inherit', opacity: 0.7 }}>Privacy</a>
        {' · '}
        <a href="/imprint" style={{ color: 'inherit', opacity: 0.7 }}>Imprint</a>
      </p>
    </div>
  );
}
