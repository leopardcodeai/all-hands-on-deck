/**
 * Pure reducer for session events — kept separate from `SessionClient` so the
 * wire-format consumption can be tested without bringing Firebase along.
 *
 * `SessionClient` owns the IO side (Firebase listeners, blob URL lifecycle);
 * this module owns the "what does this event mean for our local view?" rules.
 */

import type { WireEvent, PhotoSessionDTO } from './wire';

export type SessionStatus = 'idle' | 'connecting' | 'connected' | 'lost' | 'ended' | 'notFound';

export interface SessionState {
  status: SessionStatus;
  metadata?: PhotoSessionDTO;
  countdownTargetMs?: number;
  countdownDuration?: number;
  /** Base64 JPEG of the final photo, if delivered. The blob URL is owned by SessionClient. */
  finalPhotoBase64?: string;
}

export const initialState: SessionState = { status: 'idle' };

/**
 * Apply a wire event to the session state. Pure: never touches `URL`, `Blob`,
 * `crypto`, or any browser API. Caller decides what to do with side-effect
 * fields like `finalPhotoBase64` (e.g. turn it into an object URL).
 */
export function applyEvent(state: SessionState, event: WireEvent): SessionState {
  if ('sessionMetadata' in event) {
    return { ...state, metadata: event.sessionMetadata };
  }
  if ('countdownStarted' in event) {
    const targetMs = Date.parse(event.countdownStarted.photoAt);
    return {
      ...state,
      countdownTargetMs: Number.isFinite(targetMs) ? targetMs : undefined,
      countdownDuration: event.countdownStarted.duration,
    };
  }
  if ('countdownCancelled' in event) {
    return { ...state, countdownTargetMs: undefined, countdownDuration: undefined };
  }
  if ('photoCaptured' in event) {
    return { ...state, countdownTargetMs: undefined, countdownDuration: undefined };
  }
  if ('finalPhotoAvailable' in event) {
    return { ...state, finalPhotoBase64: event.finalPhotoAvailable.jpeg };
  }
  if ('sessionEnded' in event) {
    return { ...state, status: 'ended' };
  }
  // Other event kinds (participantJoined/Left, reactionSent, captureRequested,
  // captureApproved/Denied, previewFrame) don't influence the viewer-side state
  // tracked here. Frames flow through a separate channel.
  return state;
}
