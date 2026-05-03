import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { DesignLabels } from './DesignLabels';

const APP_VERSION = '2.3.9';

export function HomePage() {
  const navigate = useNavigate();
  const [code, setCode] = useState('');

  return (
    <div className="center-stack">
      <span className="pill pill-gold">⚓︎ {DesignLabels.byCaptainLeopard}</span>
      <h1 className="title">{DesignLabels.appName}</h1>
      <p className="subtitle">{DesignLabels.homeSubtitle}</p>
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
        {DesignLabels.joinArrow}
      </button>
      <p className="muted-note">{DesignLabels.noInstall}</p>
      <p className="muted-note" style={{ marginTop: 24, fontSize: 11 }}>
        <a href="/privacy" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.privacy}</a>
        {' · '}
        <a href="/imprint" style={{ color: 'inherit', opacity: 0.7 }}>{DesignLabels.imprint}</a>
      </p>
    </div>
  );
}
