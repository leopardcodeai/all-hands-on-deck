import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { startCamera, type CameraCapture } from './CameraCapture';
import { HostClient, type HostState } from './HostClient';
import { DesignLabels } from './DesignLabels';
import { QRCodePanel } from './components/QRCodePanel';

const TIMER_OPTIONS = [5, 10, 20, 30];
type TriggerPermission = 'hostOnly' | 'everyoneCanStartTimer' | 'viewersCanRequest';

export function HostPage() {
  const navigate = useNavigate();
  const [camera, setCamera] = useState<CameraCapture | null>(null);
  const [camError, setCamError] = useState<string | null>(null);
  const [state, setState] = useState<HostState | null>(null);
  const [flash, setFlash] = useState(false);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [crewOpen, setCrewOpen] = useState(false);
  const [showQR, setShowQR] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [timerDuration, setTimerDuration] = useState(10);
  const [triggerPermission, setTriggerPermission] = useState<TriggerPermission>('everyoneCanStartTimer');
  const [jpegQuality, setJpegQuality] = useState(0.3);
  const [frameWidth, setFrameWidth] = useState(240);
  const videoRef = useRef<HTMLVideoElement>(null);

  const client = useMemo(() => new HostClient(), []);

  useEffect(() => {
    const unsub = client.subscribe(setState);
    return () => { unsub(); client.stop(); };
  }, [client]);

  useEffect(() => {
    if (camera && videoRef.current) {
      videoRef.current.srcObject = camera.stream;
      void videoRef.current.play().catch(() => {});
    }
  }, [camera]);

  // Auto-start session immediately on mount
  useEffect(() => {
    void (async () => {
      if (state !== null) return;
      try {
        const cam = await startCamera();
        setCamera(cam);
        await client.startSession('Captain');
      } catch (e: unknown) {
        if (e instanceof DOMException && e.name === 'NotAllowedError') {
          setCamError('Camera access denied.');
        } else if (e instanceof DOMException && e.name === 'NotFoundError') {
          setCamError('No camera found.');
        } else {
          setCamError(String(e));
        }
      }
    })();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const capturePhoto = useCallback(async () => {
    if (!camera || !state || state.status !== 'active') return;
    setCountdown(timerDuration);
    for (let i = timerDuration - 1; i >= 0; i--) {
      await new Promise(r => setTimeout(r, 1000));
      setCountdown(i);
    }
    setCountdown(null);
    setFlash(true);
    setTimeout(() => setFlash(false), 220);
    const jpeg = camera.capturePhoto();
    await client.sendFinalPhoto(jpeg);
  }, [camera, client, state, timerDuration]);

  const captureNow = useCallback(async () => {
    if (!camera || !state || state.status !== 'active') return;
    setFlash(true);
    setTimeout(() => setFlash(false), 220);
    const jpeg = camera.capturePhoto();
    await client.sendFinalPhoto(jpeg);
  }, [camera, client, state]);

  const endSession = useCallback(() => {
    camera?.stop();
    client.stop();
    navigate('/');
  }, [camera, client, navigate]);

  const isIdle = !state || state.status === 'idle' || state.status === 'creating';

  return (
    <div className="preview-stage">
      <video
        ref={videoRef}
        autoPlay playsInline muted
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
      />

      {isIdle ? (
        <div className="center-stack" style={{ position: 'relative', zIndex: 20, background: 'var(--abyss)', height: '100%' }}>
          <div className="placeholder-art">🏴‍☠️</div>
          {camError ? (
            <>
              <p className="subtitle" style={{ fontSize: 16, color: 'var(--crimson)' }}>{camError}</p>
              <button className="btn-primary" onClick={() => { setCamError(null); window.location.reload(); }}>Try Again</button>
            </>
          ) : (
            <>
              <p className="title" style={{ fontSize: 26, marginBottom: 4 }}>{DesignLabels.appName}</p>
              <p className="subtitle">{state?.status === 'creating' ? 'Creating session…' : 'Starting…'}</p>
            </>
          )}
          <button className="btn-secondary" onClick={() => navigate('/')} style={{ marginTop: 8 }}>{DesignLabels.back}</button>
        </div>
      ) : (
        <>
          <div className="scrim-top" />
          <div className="scrim-bottom" />

          <div className="host-topbar">
            <div className="host-topbar-row">
              <button className="icon-button" onClick={endSession} aria-label={DesignLabels.back}>‹</button>
              <span className="pill pill-signal">{DesignLabels.statusLive}</span>
              <div style={{ flex: 1 }} />
              <QRToggleButton show={showQR} onToggle={() => setShowQR(o => !o)} />
              <CrewButton count={state.participants.length} open={crewOpen} onToggle={() => { setShowSettings(false); setCrewOpen(o => !o); }} />
              <button className="icon-button" onClick={() => { const o = !showSettings; setShowSettings(o); if (o) { setCrewOpen(false); setShowQR(false); } }} aria-label={DesignLabels.settings}>⚙</button>
            </div>
          </div>

          <FrameSender camera={camera!} client={client} active={state.status === 'active' && !state.finalPhotoBase64} />

          {countdown !== null && countdown > 0 && <div className="countdown">{countdown > 9 ? '' : countdown}</div>}
          <div className={`flash${flash ? ' on' : ''}`} />

          {showQR && !showSettings && !state.finalPhotoBase64 && (
            <div className="overlay-qr">
              <QRCodePanel payload={`${window.location.origin}/join/${state.sessionCode}?session_id=${state.sessionId}&token=${crypto.randomUUID()}&expires_at=${new Date(Date.now() + 600_000).toISOString()}`} sessionCode={state.sessionCode} />
            </div>
          )}

          {!state.finalPhotoBase64 && !showSettings && (
            <div className="overlay-bottom">
              {countdown !== null ? (
                <button className="btn-primary" style={{ background: 'var(--crimson)', boxShadow: '0 8px 24px rgba(235,88,92,0.35)', width: '100%', maxWidth: 320 }} onClick={() => { setCountdown(null); }}>✕ {DesignLabels.cancel}</button>
              ) : (
                <div className="overlay-bottom-inner">
                  <button className="btn-primary" style={{ flex: 1 }} onClick={capturePhoto}>⏱ {DesignLabels.timer(timerDuration)}</button>
                  <button className="btn-secondary" style={{ flex: 0 }} onClick={captureNow}>⚡ {DesignLabels.now}</button>
                </div>
              )}
            </div>
          )}

          {state.finalPhotoBase64 && (
            <div className="final-photo" style={{ zIndex: 20 }}>
              <img src={state.finalPhotoBase64} alt="Captured" />
              <div style={{ display: 'flex', gap: 10 }}>
                <button className="btn-secondary" onClick={() => { client.clearFinalPhoto(); setFlash(false); setCountdown(null); }}>🔄 {DesignLabels.retake}</button>
                <button className="btn-primary" onClick={() => { const a = document.createElement('a'); a.href = state.finalPhotoBase64!; a.download = `crew-photo-${state.sessionCode}.jpg`; a.click(); }}>💾 {DesignLabels.save}</button>
              </div>
            </div>
          )}

          {showSettings && (
            <>
              <div className="app-backdrop open" onClick={() => setShowSettings(false)} />
              <div className="app-panel open">
                <div className="grabber" />
                <h3>{DesignLabels.settings}</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, overflow: 'auto' }}>
                  <div>
                    <p style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--mist)', margin: '0 0 6px' }}>{DesignLabels.timer(timerDuration)}</p>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {TIMER_OPTIONS.map(s => (
                        <button key={s} className={s === timerDuration ? 'btn-primary' : 'btn-secondary'} style={{ padding: '10px 16px', fontSize: 13, flex: 1 }} onClick={() => setTimerDuration(s)}>{s}s</button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <p style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--mist)', margin: '0 0 6px' }}>Trigger Permission</p>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      {(['hostOnly', 'everyoneCanStartTimer', 'viewersCanRequest'] as const).map(p => (
                        <button key={p} className={p === triggerPermission ? 'btn-primary' : 'btn-secondary'} style={{ padding: '10px 14px', fontSize: 12, textAlign: 'left', justifyContent: 'flex-start' }} onClick={() => setTriggerPermission(p)}>
                          {p === 'hostOnly' ? '👑 Captain Only' : p === 'everyoneCanStartTimer' ? '👥 Crew can trigger' : '🙋 Crew asks — Captain decides'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <p style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--mist)', margin: '0 0 6px' }}>Quality</p>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      <div>
                        <label style={{ fontSize: 11, color: 'var(--mist)' }}>JPEG Quality</label>
                        <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                          {[0.2, 0.3, 0.5, 0.7].map(q => (
                            <button key={q} className={q === jpegQuality ? 'btn-primary' : 'btn-secondary'} style={{ padding: '8px 12px', fontSize: 11, flex: 1 }} onClick={() => setJpegQuality(q)}>{Math.round(q * 100)}%</button>
                          ))}
                        </div>
                      </div>
                      <div style={{ marginTop: 4 }}>
                        <label style={{ fontSize: 11, color: 'var(--mist)' }}>Frame Size</label>
                        <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                          {[120, 240, 480].map(w => (
                            <button key={w} className={w === frameWidth ? 'btn-primary' : 'btn-secondary'} style={{ padding: '8px 12px', fontSize: 11, flex: 1 }} onClick={() => setFrameWidth(w)}>{w}p</button>
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <button className="btn-secondary" onClick={() => setShowSettings(false)} style={{ marginTop: 8 }}>{DesignLabels.close}</button>
              </div>
            </>
          )}

          {crewOpen && (
            <>
              <div className="crew-backdrop open" onClick={() => setCrewOpen(false)} />
              <div className="crew-panel open">
                <div className="grabber" />
                <h3>{DesignLabels.crew} ({state.participants.length})</h3>
                <div className="crew-list">
                  <div className="crew-row me">
                    <span className="crew-rank">🏴‍☠️</span>
                    <span className="crew-name">Captain (You)</span>
                    <span className="crew-conn">🌐</span>
                  </div>
                  {state.participants.map(p => (
                    <div className="crew-row" key={p.id}>
                      <span className="crew-rank">👤</span>
                      <span className="crew-name">{p.displayName}</span>
                      <span className="crew-conn">{p.connectionType === 'web' ? '🌐' : '📱'}</span>
                    </div>
                  ))}
                </div>
                {state.participants.length === 0 && <p className="muted-note" style={{ textAlign: 'center', padding: 8 }}>{DesignLabels.hostNoViewers}</p>}
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}

function QRToggleButton({ show, onToggle }: { show: boolean; onToggle: () => void }) {
  return (
    <button
      className="icon-button"
      style={{ background: show ? 'linear-gradient(135deg, var(--gold), var(--amber))' : undefined, borderColor: show ? 'transparent' : undefined, color: show ? 'black' : undefined }}
      onClick={onToggle}
      aria-label={show ? DesignLabels.hideQRCode : DesignLabels.showQRCode}
    >
      {show ? '◈' : '◇'}
    </button>
  );
}

function CrewButton({ count, open, onToggle }: { count: number; open: boolean; onToggle: () => void }) {
  return (
    <button className="icon-button" style={{ position: 'relative', background: open ? 'linear-gradient(135deg, var(--gold), var(--amber))' : undefined, borderColor: open ? 'transparent' : undefined, color: open ? 'black' : undefined }} onClick={onToggle} aria-label={DesignLabels.crew}>
      {DesignLabels.iconCrew}
      {count > 0 && (
        <span style={{ position: 'absolute', top: -4, right: -4, width: 16, height: 16, borderRadius: '50%', background: 'linear-gradient(135deg, var(--gold), var(--amber))', color: 'black', fontSize: 9, fontWeight: 900, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {count}
        </span>
      )}
    </button>
  );
}

function FrameSender({ camera, client, active, quality = 0.3, frameWidth = 240 }: {
  camera: CameraCapture; client: HostClient; active: boolean; quality?: number; frameWidth?: number;
}) {
  const ref = useRef<number | null>(null);
  useEffect(() => {
    if (!active) { if (ref.current) { clearInterval(ref.current); ref.current = null; } return; }
    ref.current = window.setInterval(() => { void client.sendPreviewFrame(camera.captureFrame(quality, frameWidth)); }, 333);
    return () => { if (ref.current) clearInterval(ref.current); };
  }, [camera, client, active, quality, frameWidth]);
  return null;
}
