import { memo, useEffect, useMemo, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { SessionClient } from './SessionClient';
import { ReactionStrip } from './ReactionStrip';
import { getOrAssignRank } from './pirateRank';

// Isolated frame viewer — updates img.src via DOM ref so the parent never
// re-renders at 3fps. Only re-renders once when the first frame arrives.
const FrameImage = memo(function FrameImage({ client }: { client: SessionClient }) {
  const imgRef   = useRef<HTMLImageElement>(null);
  const shownRef = useRef(!!client.latestFrameURL);
  const [hasFrame, setHasFrame] = useState(!!client.latestFrameURL);

  useEffect(() => {
    return client.subscribeFrame((url) => {
      if (imgRef.current) imgRef.current.src = url;
      if (!shownRef.current) {
        shownRef.current = true;
        setHasFrame(true);
      }
    });
  }, [client]);

  return (
    <>
      <img
        ref={imgRef}
        src={hasFrame ? (client.latestFrameURL ?? '') : ''}
        alt="Live preview"
        style={{ display: hasFrame ? undefined : 'none' }}
      />
      {!hasFrame && (
        <div className="center-stack">
          <div className="placeholder-art">📷</div>
          <p className="subtitle">Waiting for Captain&apos;s framing…</p>
        </div>
      )}
    </>
  );
});

// Extract a leading emoji (Extended_Pictographic) from a display name, if any.
function leadingEmoji(name: string | undefined): string | null {
  if (!name) return null;
  try {
    const m = name.match(/^(\p{Extended_Pictographic})/u);
    return m?.[1] ?? null;
  } catch {
    return null;
  }
}

function connectionIcon(p: { role: string; connectionType: string }): string {
  if (p.role === 'host') return '👑';
  if (p.connectionType === 'web') return '🌐';
  if (p.connectionType === 'mock') return '🤖';
  return '📱';
}

export function JoinPage() {
  const { sessionId } = useParams<{ sessionId: string }>();
  const navigate = useNavigate();
  const rank = useMemo(() => getOrAssignRank(), []);
  const client = useMemo(() => new SessionClient(sessionId ?? '', rank), [sessionId, rank]);

  const [, force] = useState(0);
  const [flash, setFlash] = useState(false);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [dismissedPhoto, setDismissedPhoto] = useState(false);
  const [crewOpen, setCrewOpen] = useState(false);
  const tickRef = useRef<number | null>(null);

  useEffect(() => { setDismissedPhoto(false); }, [client.finalPhotoURL]);

  useEffect(() => {
    // General events only — frame updates are handled by FrameImage via subscribeFrame.
    const unsub = client.subscribe(() => force(n => n + 1));
    client.connect();
    return () => {
      unsub();
      client.disconnect();
    };
  }, [client]);

  // Local countdown ticker driven off photoAt — same model as iOS.
  useEffect(() => {
    if (tickRef.current) cancelAnimationFrame(tickRef.current);
    if (!client.countdownTargetMs) {
      setRemaining(null);
      return;
    }
    const loop = () => {
      const target = client.countdownTargetMs;
      if (!target) { setRemaining(null); return; }
      const r = Math.max(0, target - Date.now());
      const secs = Math.ceil(r / 1000);
      setRemaining(secs > 0 ? secs : 0);
      if (r <= 0) {
        setFlash(true);
        setTimeout(() => setFlash(false), 220);
        return;
      }
      tickRef.current = requestAnimationFrame(loop);
    };
    tickRef.current = requestAnimationFrame(loop);
    return () => { if (tickRef.current) cancelAnimationFrame(tickRef.current); };
  }, [client.countdownTargetMs, force]);

  const meta = client.metadata;
  // Show trigger buttons by default when no metadata yet; hide only when host explicitly set hostOnly.
  const canTrigger = !meta || meta.triggerPermission === 'everyoneCanStartTimer';
  const canRequest = meta?.triggerPermission === 'viewersCanRequest';

  const statusPill = (() => {
    switch (client.status) {
      case 'connecting': return <span className="pill pill-amber">⌛ Connecting</span>;
      case 'connected':  return <span className="pill pill-signal">● Connected</span>;
      case 'lost':       return <span className="pill pill-crimson">⚠ Connection lost</span>;
      case 'ended':      return <span className="pill pill-gold">⚑ Ended</span>;
      case 'notFound':   return <span className="pill pill-crimson">? Not found</span>;
      default:           return null;
    }
  })();

  return (
    <div className="preview-stage">
      <FrameImage client={client} />

      <div className="scrim-top" />
      <div className="scrim-bottom" />

      <div className="top-bar">
        <button
          onClick={() => navigate('/')}
          style={{
            background: 'rgba(255,255,255,0.08)',
            border: '1px solid rgba(255,255,255,0.12)',
            color: 'var(--bone)',
            flexShrink: 0,
            width: 40, height: 40, borderRadius: '50%',
            fontSize: 16, fontWeight: 800
          }}
        >‹</button>
        {statusPill}
        <div style={{ flex: 1, minWidth: 0 }} />
        <span className="pill pill-gold" style={{
          fontFamily: 'SF Mono, ui-monospace, monospace',
          maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
        }}>
          {sessionId}
        </span>
        <span className="pill pill-amber" style={{ fontSize: 11, flexShrink: 0 }}>
          {rank.split(' ')[0]}
        </span>
        <button
          aria-label="Crew"
          onClick={() => setCrewOpen(true)}
          className="icon-button"
        >
          ⚙
        </button>
      </div>

      <div className="bottom-bar">
        {client.status === 'connected' && remaining === null && (
          <ReactionStrip onReact={(id) => client.sendReaction(id)} />
        )}
        {client.status === 'connected' && canTrigger && remaining === null && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <button className="btn-primary" onClick={() => client.sendCaptureRequest()}>
              ⏱ Timer {meta?.timerDuration != null ? `${meta.timerDuration}s` : ''}
            </button>
            <button className="btn-secondary" onClick={() => client.sendCaptureNowRequest()}>
              ⚡ Now
            </button>
          </div>
        )}
        {client.status === 'connected' && canRequest && remaining === null && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <button className="btn-primary" onClick={() => client.sendCaptureRequest()}>
              📸 Request Photo
            </button>
          </div>
        )}
        {client.status === 'connected' && remaining !== null && (
          <span className="pill pill-signal">Hold still — smile!</span>
        )}
      </div>

      {remaining !== null && remaining > 0 && (
        <div className="countdown">{remaining}</div>
      )}
      <div className={`flash ${flash ? 'on' : ''}`} />

      {client.finalPhotoURL && !dismissedPhoto && (
        <div className="final-photo" style={{ overflowY: 'auto', padding: '24px 16px' }}>
          <img src={client.finalPhotoURL} alt="Final crew photo" />
          {'share' in navigator ? (
            <button
              className="btn-primary"
              onClick={async () => {
                try {
                  const resp = await fetch(client.finalPhotoURL!);
                  const blob = await resp.blob();
                  const file = new File([blob], `crewphoto-${sessionId}.jpg`, { type: 'image/jpeg' });
                  await navigator.share({ files: [file], title: 'Crew Photo' });
                } catch {
                  // share cancelled or failed — ignore
                }
              }}
            >
              ↑ Share / Save
            </button>
          ) : (
            <a
              className="btn-primary"
              href={client.finalPhotoURL}
              download={`crewphoto-${sessionId}.jpg`}
            >
              ↓ Save
            </a>
          )}
          <button
            className="btn-secondary"
            onClick={() => setDismissedPhoto(true)}
          >
            Done
          </button>
        </div>
      )}

      <div
        className={`crew-backdrop ${crewOpen ? 'open' : ''}`}
        onClick={() => setCrewOpen(false)}
      />
      <div className={`crew-panel ${crewOpen ? 'open' : ''}`} role="dialog" aria-label="Crew">
        <div className="grabber" />
        <h3>Crew</h3>
        <div className="crew-list">
          {(meta?.participants ?? []).length === 0 && (
            <div className="muted-note" style={{ textAlign: 'center', padding: '14px 0' }}>
              No crew yet — waiting for the captain&apos;s manifest…
            </div>
          )}
          {(meta?.participants ?? []).map((p) => {
            const emoji = leadingEmoji(p.displayName) ?? '🏴‍☠️';
            const isMe = p.id === client.participantId;
            return (
              <div key={p.id} className={`crew-row ${isMe ? 'me' : ''}`}>
                <span className="crew-rank" aria-hidden>{emoji}</span>
                <span className="crew-name">{p.displayName}</span>
                <span className="crew-conn" aria-hidden>{connectionIcon(p)}</span>
              </div>
            );
          })}
        </div>
        <button className="btn-secondary" onClick={() => setCrewOpen(false)}>
          Close
        </button>
      </div>

      {(client.status === 'lost' || client.status === 'ended' || client.status === 'notFound') &&
       !client.finalPhotoURL && (
        <div className="final-photo" style={{ padding: '24px 16px' }}>
          <div className="placeholder-art">
            {client.status === 'ended' ? '⚑' : client.status === 'lost' ? '⚠' : '?'}
          </div>
          <h2 style={{ margin: 0, textAlign: 'center' }}>
            {client.status === 'ended'    ? 'Session ended' :
             client.status === 'lost'     ? 'Connection lost' :
                                            'Session not found'}
          </h2>
          <button className="btn-secondary" onClick={() => navigate('/')}>
            Back
          </button>
        </div>
      )}
    </div>
  );
}
