export interface LiveKitTokenResponse {
  token: string;
  url: string;
}

export async function getLiveKitToken(sessionId: string, participantId: string): Promise<LiveKitTokenResponse> {
  const response = await fetch('/api/livekit/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_id: sessionId, participant_id: participantId }),
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || 'Live Beta token could not be created.');
  }

  return response.json() as Promise<LiveKitTokenResponse>;
}
