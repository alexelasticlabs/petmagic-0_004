import type {
  AdminTemplateGenerationCapacityAlert,
  AdminTemplateGenerationCapacityProfile,
} from "@/lib/api-client";

const BASE_GLOBAL_LIMIT = 8;
const MAX_PERSISTED_ALERT_TRANSITIONS = 64;
const MAX_ALERT_TRANSITION_KEY_LENGTH = 360;
const GENERATION_CAPACITY_ALERT_TRANSITIONS_STORAGE_KEY_PREFIX =
  "petmagic.admin.generation-capacity-alert-transitions.v1";

const BASE_PROFILE = {
  imageReservedConcurrentGenerations: 3,
  imageProtectedConcurrentGenerations: 3,
  imageMaxConcurrentGenerations: 7,
  videoReservedConcurrentGenerations: 2,
  videoMaxConcurrentGenerations: 4,
  videoBorrowMaxConcurrentGenerations: 2,
  videoPreprocessingMaxConcurrentGenerations: 1,
} as const;

function scalePositiveCapacity(baseValue: number, effectiveGlobalLimit: number): number {
  if (effectiveGlobalLimit <= 0) {
    return 0;
  }

  return Math.max(1, Math.round((baseValue * effectiveGlobalLimit) / BASE_GLOBAL_LIMIT));
}

export function calculateEffectiveGlobalLimit(
  confirmedFalConcurrencyLimit: number,
  reservedHeadroom: number,
  applicationHardCeiling: number
): number {
  const providerCapacity = Math.max(
    0,
    Math.floor(confirmedFalConcurrencyLimit) - Math.max(0, Math.floor(reservedHeadroom))
  );
  return Math.max(0, Math.min(Math.max(0, Math.floor(applicationHardCeiling)), providerCapacity));
}

export function calculateBalancedGenerationProfile(
  confirmedFalConcurrencyLimit: number,
  reservedHeadroom: number,
  applicationHardCeiling: number
): AdminTemplateGenerationCapacityProfile {
  const globalMaxConcurrentGenerations = calculateEffectiveGlobalLimit(
    confirmedFalConcurrencyLimit,
    reservedHeadroom,
    applicationHardCeiling
  );
  const imageReservedConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    scalePositiveCapacity(
      BASE_PROFILE.imageReservedConcurrentGenerations,
      globalMaxConcurrentGenerations
    )
  );
  const imageProtectedConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    scalePositiveCapacity(
      BASE_PROFILE.imageProtectedConcurrentGenerations,
      globalMaxConcurrentGenerations
    )
  );
  const videoReservedConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    scalePositiveCapacity(
      BASE_PROFILE.videoReservedConcurrentGenerations,
      globalMaxConcurrentGenerations
    )
  );
  const videoMaxConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    Math.max(
      videoReservedConcurrentGenerations,
      scalePositiveCapacity(
        BASE_PROFILE.videoMaxConcurrentGenerations,
        globalMaxConcurrentGenerations
      )
    )
  );

  return {
    globalMaxConcurrentGenerations,
    imageReservedConcurrentGenerations,
    imageProtectedConcurrentGenerations,
    imageMaxConcurrentGenerations: Math.min(
      globalMaxConcurrentGenerations,
      scalePositiveCapacity(
        BASE_PROFILE.imageMaxConcurrentGenerations,
        globalMaxConcurrentGenerations
      )
    ),
    videoReservedConcurrentGenerations,
    videoMaxConcurrentGenerations,
    videoBorrowMaxConcurrentGenerations: Math.min(
      videoMaxConcurrentGenerations,
      scalePositiveCapacity(
        BASE_PROFILE.videoBorrowMaxConcurrentGenerations,
        globalMaxConcurrentGenerations
      )
    ),
    videoPreprocessingMaxConcurrentGenerations: Math.min(
      videoMaxConcurrentGenerations,
      scalePositiveCapacity(
        BASE_PROFILE.videoPreprocessingMaxConcurrentGenerations,
        globalMaxConcurrentGenerations
      )
    ),
  };
}

export function buildGenerationCapacityAlertTransitionKey(
  alert: Pick<AdminTemplateGenerationCapacityAlert, "alertId" | "statusChangedAtUtc">
): string {
  const alertId = alert.alertId.trim();
  const statusChangedAtUtc = alert.statusChangedAtUtc.trim();
  return alertId && statusChangedAtUtc ? `${alertId}:${statusChangedAtUtc}` : "";
}

export function getGenerationCapacityAlertTransitionsStorageKey(
  userId: string | null | undefined
): string | null {
  const normalizedUserId = userId?.trim();
  return normalizedUserId
    ? `${GENERATION_CAPACITY_ALERT_TRANSITIONS_STORAGE_KEY_PREFIX}:${encodeURIComponent(normalizedUserId)}`
    : null;
}

export function parseGenerationCapacityAlertTransitions(rawValue: string | null): string[] {
  if (!rawValue) {
    return [];
  }

  try {
    const parsed = JSON.parse(rawValue) as unknown;
    if (!Array.isArray(parsed)) {
      return [];
    }

    const uniqueTransitions = new Set<string>();
    for (const value of parsed) {
      if (
        typeof value !== "string" ||
        !value.trim() ||
        value.length > MAX_ALERT_TRANSITION_KEY_LENGTH
      ) {
        continue;
      }

      uniqueTransitions.add(value);
    }

    return Array.from(uniqueTransitions).slice(-MAX_PERSISTED_ALERT_TRANSITIONS);
  } catch {
    return [];
  }
}

export function retainRecentGenerationCapacityAlertTransitions(
  transitionKeys: Iterable<string>
): string[] {
  const uniqueTransitions = new Set<string>();
  for (const transitionKey of transitionKeys) {
    if (transitionKey && transitionKey.length <= MAX_ALERT_TRANSITION_KEY_LENGTH) {
      uniqueTransitions.add(transitionKey);
    }
  }

  return Array.from(uniqueTransitions).slice(-MAX_PERSISTED_ALERT_TRANSITIONS);
}

export function isGenerationCapacityDecrease(
  currentEffectiveGlobalLimit: number,
  nextProfile: AdminTemplateGenerationCapacityProfile
): boolean {
  return nextProfile.globalMaxConcurrentGenerations < currentEffectiveGlobalLimit;
}
