import { useEffect, useRef, useState } from 'react';
import { toCanvas } from 'qrcode';
import { DesignLabels } from '../DesignLabels';

export function QRCodePanel({ payload, sessionCode }: { payload: string; sessionCode: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!canvasRef.current) return;
    toCanvas(canvasRef.current, payload, {
      width: 168,
      margin: 2,
      color: { dark: '#f5f3e8', light: '#0a0c11' },
    });
  }, [payload]);

  useEffect(() => {
    if (!copied) return;
    const t = setTimeout(() => setCopied(false), 2000);
    return () => clearTimeout(t);
  }, [copied]);

  return (
    <div className="glass" style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, width: '100%', maxWidth: 280 }}>
      <div style={{ position: 'relative', width: 168, height: 168, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <canvas ref={canvasRef} width={168} height={168} style={{ borderRadius: 12 }} />
        <span style={{ position: 'absolute', fontSize: 24 }}>🏴‍☠️</span>
      </div>
      <p style={{ margin: 0, fontSize: 20, fontWeight: 900, fontFamily: '"SF Mono", monospace', letterSpacing: '0.08em', color: 'var(--bone)' }}>
        {sessionCode}
      </p>
      <div style={{ display: 'flex', gap: 6, width: '100%' }}>
        <button className="btn-secondary" style={{ flex: 1, padding: '10px 12px', fontSize: 12 }} onClick={async () => {
          await navigator.clipboard?.writeText(payload);
          setCopied(true);
        }}>
          {copied ? '✓ ' : '📋 '}{copied ? DesignLabels.copied : DesignLabels.copyLink}
        </button>
      </div>
    </div>
  );
}
