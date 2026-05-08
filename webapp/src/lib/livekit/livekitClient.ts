import { Room, RoomEvent, Track, type RemoteParticipant, type RemoteTrack, type RemoteTrackPublication } from 'livekit-client';
import { getLiveKitToken } from './getLiveKitToken';

export function isLiveKitBetaEnabled(): boolean {
  const env = import.meta.env as Record<string, string | undefined>;
  return (env.VITE_ENABLE_LIVEKIT_BETA ?? env.NEXT_PUBLIC_ENABLE_LIVEKIT_BETA) === 'true';
}

export interface LiveKitSession {
  room: Room;
  disconnect: () => void;
}

export interface LiveKitConnectOptions {
  onParticipantChange?: (participants: RemoteParticipant[]) => void;
  /**
   * Fired when a remote video or audio track becomes available — pass the
   * track's MediaStreamTrack to your <video>/<audio> element via track.attach().
   * Webapp viewers only need video; audio path stays optional for later.
   */
  onTrackSubscribed?: (track: RemoteTrack, publication: RemoteTrackPublication, participant: RemoteParticipant) => void;
  onTrackUnsubscribed?: (track: RemoteTrack, publication: RemoteTrackPublication, participant: RemoteParticipant) => void;
}

export async function connectLiveKitBeta(
  sessionId: string,
  participantId: string,
  options: LiveKitConnectOptions = {},
): Promise<LiveKitSession> {
  const { token, url } = await getLiveKitToken(sessionId, participantId);
  const room = new Room({ adaptiveStream: true, dynacast: true });
  const notify = () => options.onParticipantChange?.(Array.from(room.remoteParticipants.values()));

  room
    .on(RoomEvent.ParticipantConnected, notify)
    .on(RoomEvent.ParticipantDisconnected, notify)
    .on(RoomEvent.Disconnected, notify)
    .on(RoomEvent.TrackSubscribed, (track, pub, participant) => {
      options.onTrackSubscribed?.(track, pub, participant);
    })
    .on(RoomEvent.TrackUnsubscribed, (track, pub, participant) => {
      options.onTrackUnsubscribed?.(track, pub, participant);
    });

  await room.connect(url, token);

  // Attach any tracks already published by participants who joined before us.
  for (const participant of room.remoteParticipants.values()) {
    for (const publication of participant.trackPublications.values()) {
      if (publication.track && publication.isSubscribed) {
        options.onTrackSubscribed?.(publication.track as RemoteTrack, publication, participant);
      }
    }
  }
  notify();

  return {
    room,
    disconnect: () => {
      room.disconnect();
    },
  };
}

export { Track };
