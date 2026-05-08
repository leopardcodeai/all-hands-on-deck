import { useEffect, useRef, useState } from 'react';
import { Track, type LocalTrack, type RemoteTrack } from 'livekit-client';
import { connectLiveKitBeta, isLiveKitBetaEnabled, type LiveKitSession } from './lib/livekit/livekitClient';
import { DesignLabels } from './DesignLabels';

interface LiveKitVideoProps {
  sessionId: string;
  participantId: string;
  /** Notifies parent when the first remote video track is attached, so the
   *  parent can hide the legacy <img> fallback (Supabase preview frames). */
  onVideoActiveChange?: (active: boolean) => void;
}

/**
 * Live Beta video viewer — auto-joins the LiveKit room when the beta flag is
 * on, then attaches the first remote video track to a local <video> element.
 * Renders nothing when the flag is off so the legacy Supabase preview path
 * stays visible. Errors are logged once and surfaced as a small muted note;
 * we never throw because the legacy path is the safety net.
 */
export function LiveKitVideo({ sessionId, participantId, onVideoActiveChange }: LiveKitVideoProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [hasVideo, setHasVideo] = useState(false);
  const [errorLabel, setErrorLabel] = useState<string | null>(null);

  useEffect(() => {
    if (!isLiveKitBetaEnabled() || !sessionId) return;

    let session: LiveKitSession | null = null;
    let cancelled = false;
    let attachedTrack: RemoteTrack | LocalTrack | null = null;

    (async () => {
      try {
        session = await connectLiveKitBeta(sessionId, participantId, {
          onTrackSubscribed: (track) => {
            if (cancelled || track.kind !== Track.Kind.Video) return;
            const el = videoRef.current;
            if (!el) return;
            if (attachedTrack) attachedTrack.detach(el);
            track.attach(el);
            attachedTrack = track;
            setHasVideo(true);
            onVideoActiveChange?.(true);
          },
          onTrackUnsubscribed: (track) => {
            if (track.kind !== Track.Kind.Video) return;
            const el = videoRef.current;
            if (el) track.detach(el);
            if (attachedTrack === track) attachedTrack = null;
            setHasVideo(false);
            onVideoActiveChange?.(false);
          },
        });
      } catch (err) {
        if (cancelled) return;
        setErrorLabel(DesignLabels.liveBetaUnavailable);
        // eslint-disable-next-line no-console
        console.warn('[LiveKitVideo] connect failed:', err);
      }
    })();

    return () => {
      cancelled = true;
      const el = videoRef.current;
      if (attachedTrack && el) attachedTrack.detach(el);
      session?.disconnect();
      onVideoActiveChange?.(false);
    };
  }, [sessionId, participantId, onVideoActiveChange]);

  if (!isLiveKitBetaEnabled()) return null;

  return (
    <>
      <video
        ref={videoRef}
        className="preview-frame"
        autoPlay
        playsInline
        muted
        style={{ display: hasVideo ? 'block' : 'none' }}
      />
      {errorLabel && !hasVideo && (
        <span className="muted-note livekit-beta-error">{errorLabel}</span>
      )}
    </>
  );
}
