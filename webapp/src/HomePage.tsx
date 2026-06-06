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
  const [activeTab, setActiveTab] = useState<'join' | 'host'>('join');

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
    <div className="center-stack" style={{ position: 'relative', overflow: 'hidden' }}>
      {/* Ambient Pulsing Background Glows */}
      <div className="bg-glow-container">
        <div className="bg-glow-1" />
        <div className="bg-glow-2" />
      </div>

      <div className="home-card">
        {/* Logo and Brand Header */}
        <div className="home-logo-container">
          <span className="home-logo-icon" aria-hidden>⚓︎</span>
          <span className="pill pill-gold" style={{ fontSize: 9, padding: '4px 10px' }}>
            {DesignLabels.byCaptainLeopard}
          </span>
        </div>

        {/* Title */}
        <h1 className="app-title-gradient">
          All Hands
          <span className="app-title-highlight">On Deck</span>
        </h1>
        <p className="app-subtitle" style={{ margin: 0 }}>
          {DesignLabels.homeSubtitle.split('\n')[0]}
        </p>

        {/* Tab Selector Segment */}
        <div className="tab-selector">
          <button
            className={`tab-btn ${activeTab === 'join' ? 'active' : ''}`}
            onClick={() => setActiveTab('join')}
          >
            {DesignLabels.join}
          </button>
          <button
            className={`tab-btn ${activeTab === 'host' ? 'active' : ''}`}
            onClick={() => setActiveTab('host')}
          >
            {DesignLabels.captain}
          </button>
        </div>

        {/* Tab 1: Join Crew */}
        {activeTab === 'join' && (
          <div className="tab-content">
            <input
              className="id-input id-input-glow"
              placeholder={DesignLabels.sessionCodePlaceholder}
              value={code}
              onChange={e => setCode(e.target.value.toUpperCase())}
              autoCapitalize="characters"
              autoCorrect="off"
              autoComplete="off"
              spellCheck={false}
              onKeyDown={e => { if (e.key === 'Enter') handleJoin(); }}
            />
            <button
              className="btn-primary btn-full btn-glow"
              disabled={extractCode(code).length < 6}
              onClick={handleJoin}
              style={{ opacity: extractCode(code).length < 6 ? 0.5 : 1 }}
            >
              ◈ {DesignLabels.joinSession}
            </button>
          </div>
        )}

        {/* Tab 2: Be the Captain */}
        {activeTab === 'host' && (
          <div className="tab-content">
            <button className="btn-primary btn-full btn-glow" onClick={() => navigate('/host')}>
              📷 {DesignLabels.startCrewPhoto}
            </button>

            <div className="join-toggle">
              <span style={{ fontSize: 18, opacity: 0.7 }}>🌐</span>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2, textAlign: 'left' }}>
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
          </div>
        )}

        <p className="muted-note" style={{ fontSize: 11, margin: 0 }}>{DesignLabels.noInstall}</p>
      </div>

      {/* Floating speech bubble for Pirate Joke */}
      <div className="joke-bubble">
        <span className="joke-emoji">🏴‍☠️</span>
        "{pirateJokes[jokeIndex]}"
      </div>

      <p className="muted-note" style={{ marginTop: 24, fontSize: 11, zIndex: 10 }}>
        <a href="/privacy" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.privacy}</a>
        {' · '}
        <a href="/imprint" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.imprint}</a>
        {' · '}
        <span style={{ opacity: 0.5 }}>v2.4.3</span>
      </p>
    </div>
  );
}
