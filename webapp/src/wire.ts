/**
 * Wire-format types — must stay in sync with iOS `SessionWireMessage` / `SessionEvent`.
 * Swift's enum-with-associated-values encodes as a single-key object, e.g.
 *   .countdownStarted(photoAt, duration, startedBy) →
 *   { "countdownStarted": { "photoAt": "...", "duration": 10, "startedBy": "id" } }
 */

export interface WireEnvelope {
  sessionId: string;
  senderId: string;
  createdAt: string; // ISO8601
  event: WireEvent;
}

export type WireEvent =
  | { sessionMetadata: PhotoSessionDTO }
  | { participantJoined: ParticipantDTO }
  | { participantLeft: { participantID: string } }
  | { participantReadyChanged: { participantID: string; isReady: boolean } }
  | { previewFrame: { jpeg: string; capturedAt: string } } // jpeg is base64
  | { countdownStarted: { photoAt: string; duration: number; startedBy: string } }
  | { countdownCancelled: { by: string } }
  | { captureRequested: { by: string } }
  | { captureNowRequested: { by: string } }
  | { captureApproved: { approvedBy: string } }
  | { captureDenied: { deniedBy: string } }
  | { photoCaptured: { at: string } }
  | { finalPhotoAvailable: { photoID: string; jpeg: string } } // base64
  | { reactionSent: { by: string; reaction: string } }
  | { sessionEnded: Record<string, never> };

export interface PhotoSessionDTO {
  id: string;
  hostName: string;
  createdAt: string;
  expiresAt: string;
  timerDuration: number;
  triggerPermission: 'hostOnly' | 'everyoneCanStartTimer' | 'viewersCanRequest';
  isDiscoverableNearby: boolean;
  allowWebJoin: boolean;
  allowFinalPhotoDownload: boolean;
  participants: ParticipantDTO[];
}

export interface ParticipantDTO {
  id: string;
  displayName: string;
  role: 'host' | 'viewer';
  joinedAt: string;
  isReady: boolean;
  connectionType: 'web' | 'nativeNearby' | 'nativeQR' | 'mock';
}
