export const GAMIFICATION_RESET_REASON_MAX_LENGTH = 500;

const CANONICAL_GUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type GamificationResetReasonError = "required" | "too_long";

export type GamificationResetReasonValidation = {
  normalizedReason: string;
  error: GamificationResetReasonError | null;
};

export function isValidGamificationUserId(value: string): boolean {
  return CANONICAL_GUID_PATTERN.test(value.trim());
}

export function calculateGamificationCompletionRate(
  completedCount: number,
  participantCount: number
): number {
  if (
    !Number.isFinite(completedCount) ||
    !Number.isFinite(participantCount) ||
    completedCount <= 0 ||
    participantCount <= 0
  ) {
    return 0;
  }

  const percentage = Math.round((completedCount / participantCount) * 100);
  return Math.min(100, Math.max(0, percentage));
}

export function validateGamificationResetReason(value: string): GamificationResetReasonValidation {
  const normalizedReason = value.trim();

  if (!normalizedReason) {
    return { normalizedReason, error: "required" };
  }

  if (normalizedReason.length > GAMIFICATION_RESET_REASON_MAX_LENGTH) {
    return { normalizedReason, error: "too_long" };
  }

  return { normalizedReason, error: null };
}
