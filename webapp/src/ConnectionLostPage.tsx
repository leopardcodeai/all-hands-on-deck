import { useNavigate } from 'react-router-dom';
import { DesignLabels } from './DesignLabels';

interface ConnectionLostPageProps {
  sessionId?: string;
}

export function ConnectionLostPage({ sessionId }: ConnectionLostPageProps) {
  const navigate = useNavigate();

  return (
    <div className="center-stack connection-lost-page">
      <span className="lost-skull">☠</span>
      <h1 className="lost-headline">{DesignLabels.overboard}</h1>
      <p className="lost-description">
        {DesignLabels.connectionLostBody}
      </p>
      <div className="lost-actions">
        {sessionId && (
          <button className="btn-primary" onClick={() => navigate(`/join/${sessionId}`)}>
            {DesignLabels.rejoin}
          </button>
        )}
        <button className="btn-secondary" onClick={() => navigate('/')}>
          {DesignLabels.home}
        </button>
      </div>
    </div>
  );
}
