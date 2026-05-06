import { describe, expect, it } from 'vitest';
import {
  DEFAULT_MVP_SESSION_POLICY,
  canJoinP2PSession,
  canSendRealtimeMessage,
  createShortLivedJoinToken,
  isJoinTokenValid,
  shouldEscalateQuotaWarning,
  shouldUseTurnFallback,
  videoStorageTableNames,
} from '../services/sessionPolicy';

describe('MVP session policy', () => {
  it('locks the free P2P MVP to explicit cost controls', () => {
    expect(DEFAULT_MVP_SESSION_POLICY.maxSessionDurationMinutes).toBe(10);
    expect(DEFAULT_MVP_SESSION_POLICY.maxP2PViewers).toBe(3);
    expect(DEFAULT_MVP_SESSION_POLICY.shortLivedTokenTtlMinutes).toBeGreaterThanOrEqual(5);
    expect(DEFAULT_MVP_SESSION_POLICY.shortLivedTokenTtlMinutes).toBeLessThanOrEqual(15);
    expect(DEFAULT_MVP_SESSION_POLICY.realtimeMessagesPerMinute).toBeLessThanOrEqual(120);
    expect(DEFAULT_MVP_SESSION_POLICY.webViewersFeatureStage).toBe('beta');
  });

  it('rejects P2P joins after the configured viewer limit', () => {
    expect(canJoinP2PSession(2)).toBe(true);
    expect(canJoinP2PSession(3)).toBe(false);
  });

  it('creates short-lived QR tokens that expire', () => {
    const issuedAt = new Date('2026-05-06T08:00:00.000Z');
    const token = createShortLivedJoinToken('session-1', issuedAt);

    expect(token.sessionId).toBe('session-1');
    expect(isJoinTokenValid(token, new Date('2026-05-06T08:10:00.000Z'))).toBe(true);
    expect(isJoinTokenValid(token, new Date('2026-05-06T08:10:01.000Z'))).toBe(false);
  });

  it('uses TURN only as explicit fallback with a hard minute limit', () => {
    expect(shouldUseTurnFallback({ explicitFallbackRequested: false, usedTurnMinutes: 0 })).toBe(false);
    expect(shouldUseTurnFallback({ explicitFallbackRequested: true, usedTurnMinutes: 0 })).toBe(true);
    expect(shouldUseTurnFallback({
      explicitFallbackRequested: true,
      usedTurnMinutes: DEFAULT_MVP_SESSION_POLICY.maxTurnMinutesPerSession,
    })).toBe(false);
  });

  it('keeps video out of Supabase storage/database scope', () => {
    expect(videoStorageTableNames()).toEqual([]);
  });

  it('rate limits realtime fallback messages per minute', () => {
    expect(canSendRealtimeMessage(119)).toBe(true);
    expect(canSendRealtimeMessage(120)).toBe(false);
  });

  it('escalates quota warnings at 50, 80, and 95 percent', () => {
    expect(shouldEscalateQuotaWarning(0.49)).toBe(null);
    expect(shouldEscalateQuotaWarning(0.5)).toBe(50);
    expect(shouldEscalateQuotaWarning(0.8)).toBe(80);
    expect(shouldEscalateQuotaWarning(0.95)).toBe(95);
  });
});
