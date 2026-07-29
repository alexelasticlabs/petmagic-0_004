import { describe, expect, it } from "vitest";

import {
  buildGenerationCapacityAlertTransitionKey,
  calculateBalancedGenerationProfile,
  calculateEffectiveGlobalLimit,
  getGenerationCapacityAlertTransitionsStorageKey,
  isGenerationCapacityDecrease,
  parseGenerationCapacityAlertTransitions,
  retainRecentGenerationCapacityAlertTransitions,
} from "@/components/generation-capacity-policy";

describe("generation capacity policy", () => {
  it("keeps two provider slots in reserve at the initial fal limit", () => {
    expect(calculateEffectiveGlobalLimit(10, 2, 38)).toBe(8);
    expect(calculateBalancedGenerationProfile(10, 2, 38)).toEqual({
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
    expect(calculateBalancedGenerationProfile(40, 2, 38)).toEqual({
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
    expect(isGenerationCapacityDecrease(8, calculateBalancedGenerationProfile(8, 2, 38))).toBe(
      true
    );
    expect(isGenerationCapacityDecrease(8, calculateBalancedGenerationProfile(10, 2, 38))).toBe(
      false
    );
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
