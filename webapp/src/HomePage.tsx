import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { DesignLabels } from './DesignLabels';

const pirateJokes = [
  "Why is pirating so addictive? Lose one hand and ye get hooked!",
  "What's a pirate's fav letter? Ye think it's R — but it's the C!",
  "How much did peg leg and hook cost? An arm and a leg!",
  "What d'ye call a pirate who skips class? Captain Hooky!",
  "Why couldn't the pirate play cards? He was standing on the deck!",
  "What's a pirate's fav country? ARRRgentina!",
  "What did the ocean say to the pirate? Nothing — it just waved!",
];

export function HomePage() {
  const navigate = useNavigate();
  const [code, setCode] = useState('');
  const [jokeIndex, setJokeIndex] = useState(0);
  const [webJoin, setWebJoin] = useState(false);

  useEffect(() => {
    setJokeIndex(Math.floor(Math.random() * pirateJokes.length));
  }, []);

  const extractCode = (input: string): string => {
    const match = input.match(/(?:join\/)?([A-Z0-9]{6,10})/i);
    return match ? match[1].toUpperCase() : input.toUpperCase().replace(/[^A-Z0-9]/g, '');
  };

  const handleJoin = () => {
    const clean = extractCode(code);
    if (clean.length >= 6) navigate(`/join/${clean}`);
  };

  return (
    <div className="center-stack">
      <div className="app-header">
        <span className="pill pill-gold">⚓︎ {DesignLabels.byCaptainLeopard}</span>
        <button className="icon-button" aria-label="Settings">⚙</button>
      </div>

      <h1 className="app-title">All Hands{'\n'}On Deck</h1>
      <p className="app-subtitle">{DesignLabels.homeSubtitle.split('\n')[0]}</p>

      <button className="btn-primary btn-full" style={{ marginBottom: 8 }} onClick={() => navigate('/host')}>
        📷 {DesignLabels.startCrewPhoto}
      </button>

      <input
        className="id-input"
        placeholder={DesignLabels.sessionCodePlaceholder}
        value={code}
        onChange={e => setCode(e.target.value)}
        autoCapitalize="characters"
        autoCorrect="off"
        autoComplete="off"
        spellCheck={false}
        style={{ marginBottom: 8 }}
        onKeyDown={e => { if (e.key === 'Enter') handleJoin(); }}
      />
      <button
        className="btn-primary btn-full"
        disabled={extractCode(code).length < 6}
        onClick={handleJoin}
        style={{ opacity: extractCode(code).length < 6 ? 0.5 : 1, marginBottom: 8 }}
      >
        ◈ {DesignLabels.joinSession}
      </button>

      <div className="join-toggle">
        <span style={{ fontSize: 18, opacity: 0.7 }}>🌐</span>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 13, fontWeight: 800, color: 'var(--bone)' }}>{DesignLabels.allowWebViewers}</span>
            <span className="beta-tag">{DesignLabels.betaBadge}</span>
          </div>
          <span style={{ fontSize: 11, color: 'var(--mist)' }}>{webJoin ? 'On — web join enabled' : 'Off — nearby only'}</span>
        </div>
        <div className="join-toggle-switch" onClick={() => setWebJoin(o => !o)}
          style={{ background: webJoin ? 'linear-gradient(135deg, var(--gold), var(--amber))' : 'rgba(255,255,255,0.15)' }}>
          <div className="join-toggle-knob" style={{ left: webJoin ? 22 : 2 }} />
        </div>
      </div>

      <p className="muted-note" style={{ marginTop: 12, fontSize: 11 }}>{DesignLabels.noInstall}</p>
      <p style={{ marginTop: 24, fontSize: 13, fontStyle: 'italic', color: 'var(--mist)', maxWidth: 300, textAlign: 'center', opacity: 0.75 }}>"{pirateJokes[jokeIndex]}"</p>
      <p className="muted-note" style={{ marginTop: 12, fontSize: 11 }}>
        <a href="/privacy" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.privacy}</a>
        {' · '}
        <a href="/imprint" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.imprint}</a>
      </p>
    </div>
  );
}
