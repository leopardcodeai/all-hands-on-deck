export interface SessionPolicy {
  maxSessionDurationMinutes: number;
  maxP2PViewers: number;
  shortLivedTokenTtlMinutes: number;
  realtimeMessagesPerMinute: number;
  maxTurnMinutesPerSession: number;
  quotaWarningThresholds: readonly number[];
  webViewersFeatureStage: 'beta';
}

export interface JoinToken {
  sessionId: string;
  token: string;
  issuedAt: string;
  expiresAt: string;
}

export const DEFAULT_MVP_SESSION_POLICY: SessionPolicy = {
  maxSessionDurationMinutes: 10,
  maxP2PViewers: 3,
  shortLivedTokenTtlMinutes: 10,
  realtimeMessagesPerMinute: 120,
  maxTurnMinutesPerSession: 2,
  quotaWarningThresholds: [0.5, 0.8, 0.95],
  webViewersFeatureStage: 'beta',
};

export function canJoinP2PSession(
  currentViewerCount: number,
  policy: SessionPolicy = DEFAULT_MVP_SESSION_POLICY,
): boolean {
  return currentViewerCount < policy.maxP2PViewers;
}

export function createShortLivedJoinToken(
  sessionId: string,
  issuedAt: Date = new Date(),
  policy: SessionPolicy = DEFAULT_MVP_SESSION_POLICY,
): JoinToken {
  const expiresAt = new Date(issuedAt.getTime() + policy.shortLivedTokenTtlMinutes * 60_000);
  return {
    sessionId,
    token: crypto.randomUUID(),
    issuedAt: issuedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
  };
}

export function isJoinTokenValid(token: JoinToken, now: Date = new Date()): boolean {
  return now.getTime() <= Date.parse(token.expiresAt);
}

export function shouldUseTurnFallback(input: {
  explicitFallbackRequested: boolean;
  usedTurnMinutes: number;
  policy?: SessionPolicy;
}): boolean {
  const policy = input.policy ?? DEFAULT_MVP_SESSION_POLICY;
  return input.explicitFallbackRequested && input.usedTurnMinutes < policy.maxTurnMinutesPerSession;
}

export function canSendRealtimeMessage(
  messagesSentInCurrentMinute: number,
  policy: SessionPolicy = DEFAULT_MVP_SESSION_POLICY,
): boolean {
  return messagesSentInCurrentMinute < policy.realtimeMessagesPerMinute;
}

export function shouldEscalateQuotaWarning(
  quotaUsageRatio: number,
  policy: SessionPolicy = DEFAULT_MVP_SESSION_POLICY,
): 50 | 80 | 95 | null {
  if (quotaUsageRatio >= policy.quotaWarningThresholds[2]) return 95;
  if (quotaUsageRatio >= policy.quotaWarningThresholds[1]) return 80;
  if (quotaUsageRatio >= policy.quotaWarningThresholds[0]) return 50;
  return null;
}

export function videoStorageTableNames(): string[] {
  return [];
}

export function makeJoinURL(baseUrl: string, token: JoinToken): string {
  const url = new URL(`/join/${token.sessionId}`, baseUrl);
  url.searchParams.set('session_id', token.sessionId);
  url.searchParams.set('token', token.token);
  url.searchParams.set('expires_at', token.expiresAt);
  return url.toString();
}
