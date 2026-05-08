export interface LiveKitTokenResponse {
  token: string;
  url: string;
}

const TOKEN_ENDPOINT = (import.meta.env.VITE_LIVEKIT_TOKEN_ENDPOINT as string | undefined)
  ?? 'https://edylzgxrknbqjdgtrgic.supabase.co/functions/v1/livekit-token';

/**
 * Calls the Supabase Edge Function `livekit-token` (verify_jwt disabled —
 * the function does its own session/participant validation against the
 * service-role-key'd database). Override the URL via `VITE_LIVEKIT_TOKEN_ENDPOINT`.
 */
export async function getLiveKitToken(sessionId: string, participantId: string): Promise<LiveKitTokenResponse> {
  const response = await fetch(TOKEN_ENDPOINT, {
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
