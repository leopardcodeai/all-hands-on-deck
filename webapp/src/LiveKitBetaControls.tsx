import { useEffect, useState } from 'react';
import { connectLiveKitBeta, isLiveKitBetaEnabled, type LiveKitSession } from './lib/livekit/livekitClient';
import { DesignLabels } from './DesignLabels';

interface LiveKitBetaControlsProps {
  sessionId: string;
  participantId: string;
}

export function LiveKitBetaControls({ sessionId, participantId }: LiveKitBetaControlsProps) {
  const [live, setLive] = useState<LiveKitSession | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => () => live?.disconnect(), [live]);

  if (!isLiveKitBetaEnabled()) return null;

  return (
    <div className="livekit-beta">
      <button
        className={live ? 'btn-secondary' : 'btn-primary'}
        onClick={async () => {
          setError(null);
          if (live) {
            live.disconnect();
            setLive(null);
            return;
          }
          try {
            setLive(await connectLiveKitBeta(sessionId, participantId));
          } catch {
            setError(DesignLabels.liveBetaUnavailable);
          }
        }}
      >
        {live ? DesignLabels.liveBetaLeave : DesignLabels.liveBetaJoin}
      </button>
      {error && <span className="muted-note">{error}</span>}
    </div>
  );
}
