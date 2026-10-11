import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { DesignLabels } from './DesignLabels';
import { parseJoinTarget } from './joinTarget';

export function HomePage() {
  const navigate = useNavigate();
  const [code, setCode] = useState('');
  const [jokeIndex, setJokeIndex] = useState(0);
  const [activeTab, setActiveTab] = useState<'join' | 'host'>('join');

  useEffect(() => {
    setJokeIndex(Math.floor(Math.random() * DesignLabels.pirateJokes.length));
  }, []);

  const joinTarget = parseJoinTarget(code);
  const handleJoin = () => {
    if (joinTarget) navigate(joinTarget);
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
          {DesignLabels.appNameFirstLine}
          <span className="app-title-highlight">{DesignLabels.appNameSecondLine}</span>
        </h1>
        <p className="app-subtitle" style={{ margin: 0 }}>
          {DesignLabels.homeSubtitle.split('\n')[0]}
        </p>

        {/* Tab Selector Segment */}
        <div className="tab-selector">
          <button
            className={`tab-btn ${activeTab === 'join' ? 'active' : ''}`}
            onClick={() => setActiveTab('join')}
            aria-pressed={activeTab === 'join'}
          >
            {DesignLabels.join}
          </button>
          <button
            className={`tab-btn ${activeTab === 'host' ? 'active' : ''}`}
            onClick={() => setActiveTab('host')}
            aria-pressed={activeTab === 'host'}
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
              onChange={e => setCode(/^[a-z0-9]*$/i.test(e.target.value) ? e.target.value.toUpperCase() : e.target.value)}
              aria-label={DesignLabels.hostSessionCode}
              data-testid="session-code"
              autoCapitalize="characters"
              autoCorrect="off"
              autoComplete="off"
              spellCheck={false}
              onKeyDown={e => { if (e.key === 'Enter') handleJoin(); }}
            />
            <button
              className="btn-primary btn-full btn-glow"
              disabled={!joinTarget}
              onClick={handleJoin}
              style={{ opacity: !joinTarget ? 0.5 : 1 }}
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

            <p className="muted-note">{DesignLabels.webHostingHint}</p>
          </div>
        )}

        <p className="muted-note" style={{ fontSize: 11, margin: 0 }}>{DesignLabels.noInstall}</p>
      </div>

      {/* Floating speech bubble for Pirate Joke */}
      <div className="joke-bubble">
        <span className="joke-emoji">🏴‍☠️</span>
        "{DesignLabels.pirateJokes[jokeIndex]}"
      </div>

      <p className="muted-note" style={{ marginTop: 24, fontSize: 11, zIndex: 10 }}>
        <a href="/privacy.html" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.privacy}</a>
        {' · '}
        <a href="/imprint.html" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.imprint}</a>
        {' · '}
        <span style={{ opacity: 0.5 }}>v2.4.4</span>
      </p>
    </div>
  );
}
