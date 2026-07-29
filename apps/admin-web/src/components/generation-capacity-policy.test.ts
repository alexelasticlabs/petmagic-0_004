import { describe, expect, it } from "vitest";

import {
  buildGenerationCapacityAlertTransitionKey,
  calculateBalancedGenerationProfile,
  calculateEffectiveGlobalLimit,
  getGenerationCapacityAlertTransitionsStorageKey,
  isGenerationCapacitySnapshotTooOld,
  isGenerationCapacityDecrease,
  parseGenerationCapacityAlertTransitions,
  retainRecentGenerationCapacityAlertTransitions,
  selectNewestGenerationCapacitySnapshot,
} from "@/components/generation-capacity-policy";
import type {
  AdminTemplateGenerationCapacityProfile,
  AdminTemplateGenerationControl,
} from "@/lib/api-client";

const baseProfile: AdminTemplateGenerationCapacityProfile = {
  globalMaxConcurrentGenerations: 8,
  imageReservedConcurrentGenerations: 3,
  imageProtectedConcurrentGenerations: 3,
  imageMaxConcurrentGenerations: 7,
  videoReservedConcurrentGenerations: 2,
  videoMaxConcurrentGenerations: 4,
  videoBorrowMaxConcurrentGenerations: 2,
  videoPreprocessingMaxConcurrentGenerations: 1,
};

function controlSnapshot(revision: number, generatedAtUtc: string): AdminTemplateGenerationControl {
  return { revision, generatedAtUtc } as AdminTemplateGenerationControl;
}

describe("generation capacity policy", () => {
  it("keeps two provider slots in reserve at the initial fal limit", () => {
    expect(calculateEffectiveGlobalLimit(10, 2, 38)).toBe(8);
    expect(calculateBalancedGenerationProfile(10, 2, 38, baseProfile)).toEqual({
      globalMaxConcurrentGenerations: 8,
      imageReservedConcurrentGenerations: 3,
      imageProtectedConcurrentGenerations: 3,
      imageMaxConcurrentGenerations: 7,
      videoReservedConcurrentGenerations: 2,
      videoMaxConcurrentGenerations: 4,
      videoBorrowMaxConcurrentGenerations: 2,
      videoPreprocessingMaxConcurrentGenerations: 1,
    });
  });

  it("scales the balanced profile to the application ceiling", () => {
    expect(calculateBalancedGenerationProfile(40, 2, 38, baseProfile)).toEqual({
      globalMaxConcurrentGenerations: 38,
      imageReservedConcurrentGenerations: 14,
      imageProtectedConcurrentGenerations: 14,
      imageMaxConcurrentGenerations: 33,
      videoReservedConcurrentGenerations: 10,
      videoMaxConcurrentGenerations: 19,
      videoBorrowMaxConcurrentGenerations: 10,
      videoPreprocessingMaxConcurrentGenerations: 5,
    });
  });

  it("marks only a lower effective limit as a capacity decrease", () => {
    expect(
      isGenerationCapacityDecrease(8, calculateBalancedGenerationProfile(8, 2, 38, baseProfile))
    ).toBe(true);
    expect(
      isGenerationCapacityDecrease(8, calculateBalancedGenerationProfile(10, 2, 38, baseProfile))
    ).toBe(false);
  });

  it("scales the preview from the base profile returned by the server", () => {
    const serverProfile: AdminTemplateGenerationCapacityProfile = {
      globalMaxConcurrentGenerations: 10,
      imageReservedConcurrentGenerations: 2,
      imageProtectedConcurrentGenerations: 4,
      imageMaxConcurrentGenerations: 8,
      videoReservedConcurrentGenerations: 3,
      videoMaxConcurrentGenerations: 6,
      videoBorrowMaxConcurrentGenerations: 1,
      videoPreprocessingMaxConcurrentGenerations: 2,
    };

    expect(calculateBalancedGenerationProfile(22, 2, 20, serverProfile)).toEqual({
      globalMaxConcurrentGenerations: 20,
      imageReservedConcurrentGenerations: 4,
      imageProtectedConcurrentGenerations: 8,
      imageMaxConcurrentGenerations: 16,
      videoReservedConcurrentGenerations: 6,
      videoMaxConcurrentGenerations: 12,
      videoBorrowMaxConcurrentGenerations: 2,
      videoPreprocessingMaxConcurrentGenerations: 4,
    });
  });

  it("never lets an older response overwrite a newer cached policy or snapshot", () => {
    const revisionFive = controlSnapshot(5, "2026-07-29T10:05:00Z");
    const lateRevisionFour = controlSnapshot(4, "2026-07-29T10:06:00Z");
    const olderSameRevision = controlSnapshot(5, "2026-07-29T10:04:00Z");
    const newerSameRevision = controlSnapshot(5, "2026-07-29T10:06:00Z");

    expect(selectNewestGenerationCapacitySnapshot(revisionFive, lateRevisionFour)).toBe(
      revisionFive
    );
    expect(selectNewestGenerationCapacitySnapshot(revisionFive, olderSameRevision)).toBe(
      revisionFive
    );
    expect(selectNewestGenerationCapacitySnapshot(revisionFive, newerSameRevision)).toBe(
      newerSameRevision
    );
  });

  it("fails closed when the control snapshot is missing, malformed, or too old", () => {
    const now = Date.parse("2026-07-29T10:02:00Z");

    expect(isGenerationCapacitySnapshotTooOld("2026-07-29T10:01:00Z", now)).toBe(false);
    expect(isGenerationCapacitySnapshotTooOld("2026-07-29T10:00:29Z", now)).toBe(true);
    expect(isGenerationCapacitySnapshotTooOld("not-a-date", now)).toBe(true);
    expect(isGenerationCapacitySnapshotTooOld(null, now)).toBe(true);
  });

  it("deduplicates alerts by the stable transition identity only", () => {
    expect(
      buildGenerationCapacityAlertTransitionKey({
        alertId: "fal-balance-low",
        statusChangedAtUtc: "2026-07-29T12:00:00Z",
      })
    ).toBe("fal-balance-low:2026-07-29T12:00:00Z");
    expect(
      buildGenerationCapacityAlertTransitionKey({
        alertId: " ",
        statusChangedAtUtc: "2026-07-29T12:00:00Z",
      })
    ).toBe("");
  });

  it("uses a versioned user-scoped storage key for durable alert transition dedupe", () => {
    expect(
      getGenerationCapacityAlertTransitionsStorageKey("11111111-1111-4111-8111-111111111111")
    ).toBe(
      "petmagic.admin.generation-capacity-alert-transitions.v1:11111111-1111-4111-8111-111111111111"
    );
    expect(getGenerationCapacityAlertTransitionsStorageKey(" ")).toBeNull();
  });

  it("hydrates only valid unique alert transition keys and retains the newest 64", () => {
    expect(
      parseGenerationCapacityAlertTransitions(
        JSON.stringify([
          "fal-balance-low:2026-07-29T12:00:00Z",
          "fal-balance-low:2026-07-29T12:00:00Z",
          "",
          42,
        ])
      )
    ).toEqual(["fal-balance-low:2026-07-29T12:00:00Z"]);
    expect(parseGenerationCapacityAlertTransitions("{not-json")).toEqual([]);

    const transitions = Array.from({ length: 70 }, (_, index) => `alert-${index}:transition`);
    const retained = retainRecentGenerationCapacityAlertTransitions(transitions);
    expect(retained).toHaveLength(64);
    expect(retained[0]).toBe("alert-6:transition");
    expect(retained.at(-1)).toBe("alert-69:transition");
  });
});
