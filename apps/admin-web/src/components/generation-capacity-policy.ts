import type {
  AdminTemplateGenerationCapacityAlert,
  AdminTemplateGenerationCapacityProfile,
  AdminTemplateGenerationControl,
} from "@/lib/api-client";

const MAX_PERSISTED_ALERT_TRANSITIONS = 64;
const MAX_ALERT_TRANSITION_KEY_LENGTH = 360;
export const GENERATION_CAPACITY_SNAPSHOT_MAX_AGE_MS = 90_000;
const GENERATION_CAPACITY_ALERT_TRANSITIONS_STORAGE_KEY_PREFIX =
  "petmagic.admin.generation-capacity-alert-transitions.v1";

function scalePositiveCapacity(
  baseValue: number,
  effectiveGlobalLimit: number,
  baseGlobalLimit: number
): number {
  if (baseValue <= 0) {
    return 0;
  }

  if (effectiveGlobalLimit <= 0) {
    return 0;
  }

  return Math.max(1, Math.round((baseValue * effectiveGlobalLimit) / baseGlobalLimit));
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
  applicationHardCeiling: number,
  baseProfile: AdminTemplateGenerationCapacityProfile
): AdminTemplateGenerationCapacityProfile {
  const globalMaxConcurrentGenerations = calculateEffectiveGlobalLimit(
    confirmedFalConcurrencyLimit,
    reservedHeadroom,
    applicationHardCeiling
  );
  if (globalMaxConcurrentGenerations <= 0) {
    return {
      globalMaxConcurrentGenerations: 0,
      imageReservedConcurrentGenerations: 0,
      imageProtectedConcurrentGenerations: 0,
      imageMaxConcurrentGenerations: 0,
      videoReservedConcurrentGenerations: 0,
      videoMaxConcurrentGenerations: 0,
      videoBorrowMaxConcurrentGenerations: 0,
      videoPreprocessingMaxConcurrentGenerations: 0,
    };
  }

  const baseGlobalLimit = Math.max(1, baseProfile.globalMaxConcurrentGenerations);
  const imageMaxConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    scalePositiveCapacity(
      baseProfile.imageMaxConcurrentGenerations,
      globalMaxConcurrentGenerations,
      baseGlobalLimit
    )
  );
  const videoMaxConcurrentGenerations = Math.min(
    globalMaxConcurrentGenerations,
    scalePositiveCapacity(
      baseProfile.videoMaxConcurrentGenerations,
      globalMaxConcurrentGenerations,
      baseGlobalLimit
    )
  );
  const imageReservedConcurrentGenerations = Math.min(
    imageMaxConcurrentGenerations,
    scalePositiveCapacity(
      baseProfile.imageReservedConcurrentGenerations,
      globalMaxConcurrentGenerations,
      baseGlobalLimit
    )
  );
  const imageProtectedConcurrentGenerations = Math.min(
    imageMaxConcurrentGenerations,
    scalePositiveCapacity(
      baseProfile.imageProtectedConcurrentGenerations,
      globalMaxConcurrentGenerations,
      baseGlobalLimit
    )
  );
  const videoReservedConcurrentGenerations = Math.min(
    videoMaxConcurrentGenerations,
    scalePositiveCapacity(
      baseProfile.videoReservedConcurrentGenerations,
      globalMaxConcurrentGenerations,
      baseGlobalLimit
    )
  );

  return {
    globalMaxConcurrentGenerations,
    imageReservedConcurrentGenerations,
    imageProtectedConcurrentGenerations,
    imageMaxConcurrentGenerations,
    videoReservedConcurrentGenerations,
    videoMaxConcurrentGenerations,
    videoBorrowMaxConcurrentGenerations: Math.min(
      videoMaxConcurrentGenerations,
      scalePositiveCapacity(
        baseProfile.videoBorrowMaxConcurrentGenerations,
        globalMaxConcurrentGenerations,
        baseGlobalLimit
      )
    ),
    videoPreprocessingMaxConcurrentGenerations: Math.min(
      Math.max(1, videoMaxConcurrentGenerations),
      scalePositiveCapacity(
        baseProfile.videoPreprocessingMaxConcurrentGenerations,
        globalMaxConcurrentGenerations,
        baseGlobalLimit
      )
    ),
  };
}

function parseUtcTimestamp(value: string): number | null {
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function selectNewestGenerationCapacitySnapshot(
  current: AdminTemplateGenerationControl | undefined,
  incoming: AdminTemplateGenerationControl
): AdminTemplateGenerationControl {
  if (!current || incoming.revision > current.revision) {
    return incoming;
  }

  if (incoming.revision < current.revision) {
    return current;
  }

  const currentGeneratedAt = parseUtcTimestamp(current.generatedAtUtc);
  const incomingGeneratedAt = parseUtcTimestamp(incoming.generatedAtUtc);
  if (currentGeneratedAt !== null && incomingGeneratedAt === null) {
    return current;
  }

  return currentGeneratedAt !== null &&
    incomingGeneratedAt !== null &&
    incomingGeneratedAt < currentGeneratedAt
    ? current
    : incoming;
}

export function isGenerationCapacitySnapshotTooOld(
  generatedAtUtc: string | null | undefined,
  nowMs: number = Date.now(),
  maximumAgeMs: number = GENERATION_CAPACITY_SNAPSHOT_MAX_AGE_MS
): boolean {
  if (!generatedAtUtc || !Number.isFinite(nowMs) || maximumAgeMs < 0) {
    return true;
  }

  const generatedAtMs = parseUtcTimestamp(generatedAtUtc);
  return generatedAtMs === null || nowMs - generatedAtMs > maximumAgeMs;
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
