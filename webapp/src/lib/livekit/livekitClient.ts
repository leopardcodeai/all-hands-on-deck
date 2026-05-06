import { Room, RoomEvent, type RemoteParticipant } from 'livekit-client';
import { getLiveKitToken } from './getLiveKitToken';

export function isLiveKitBetaEnabled(): boolean {
  const env = import.meta.env as Record<string, string | undefined>;
  return (env.VITE_ENABLE_LIVEKIT_BETA ?? env.NEXT_PUBLIC_ENABLE_LIVEKIT_BETA) === 'true';
}

export interface LiveKitSession {
  room: Room;
  disconnect: () => void;
}

export async function connectLiveKitBeta(
  sessionId: string,
  participantId: string,
  onParticipantChange?: (participants: RemoteParticipant[]) => void,
): Promise<LiveKitSession> {
  const { token, url } = await getLiveKitToken(sessionId, participantId);
  const room = new Room({ adaptiveStream: true, dynacast: true });
  const notify = () => onParticipantChange?.(Array.from(room.remoteParticipants.values()));

  room
    .on(RoomEvent.ParticipantConnected, notify)
    .on(RoomEvent.ParticipantDisconnected, notify)
    .on(RoomEvent.Disconnected, notify);

  await room.connect(url, token);
  notify();

  return {
    room,
    disconnect: () => room.disconnect(),
  };
}
