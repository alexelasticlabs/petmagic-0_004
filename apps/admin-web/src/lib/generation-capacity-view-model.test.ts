import { describe, expect, it } from "vitest";

import {
  applyGenerationCapacityPreset,
  createGenerationCapacityViewModel,
  generationCapacitySafeStartPreset,
} from "./generation-capacity-view-model";

import type { AdminGenerationControlSnapshot } from "./api-client.types.generation-control";

function createSnapshot(): AdminGenerationControlSnapshot {
  return {
    settings: {
      version: 3,
      globalMaxConcurrent: 8,
      imageMaxConcurrent: 7,
      imageProtectedConcurrent: 3,
      videoGuaranteedConcurrent: 2,
      videoMaxConcurrent: 4,
      videoBorrowMaxConcurrent: 2,
      workerLoopsPerInstance: 2,
      falConfiguredConcurrency: 10,
      falReservedConcurrency: 2,
      falBalanceLowThresholdUsd: 10,
      falBalanceCriticalThresholdUsd: 5,
      updatedAtUtc: "2026-07-28T10:00:00Z",
      updatedByAdminId: null,
    },
    status: {
      generatedAtUtc: "2026-07-28T10:01:00Z",
      activeGlobal: 2,
      activeImage: 1,
      activeVideo: 1,
      queuedImage: 0,
      queuedVideo: 0,
      effectiveImageMaxConcurrent: 7,
      borrowedVideo: 0,
      isDraining: false,
      health: "healthy",
    },
    fal: {
      configuredConcurrency: 10,
      reservedConcurrency: 1,
      usableConcurrency: 9,
      inflightRequests: 2,
      balanceUsd: 20,
      balanceStatus: "healthy",
      checkedAtUtc: "2026-07-28T10:01:00Z",
      lastSuccessAtUtc: "2026-07-28T10:01:00Z",
      isStale: false,
      providerSubmissionsAllowed: true,
      submissionBlockReason: null,
    },
    workers: [],
    render: null,
    alerts: [],
  };
}

describe("generation capacity view model", () => {
  it("reports ready when the provider gate is open and workers exceed the PetMagic limit", () => {
    const result = createGenerationCapacityViewModel(createSnapshot(), 10);

    expect(result).toEqual({
      state: "ready",
      tone: "success",
      effectiveCapacity: 8,
      bottleneck: "petmagic",
      workerCapacitySufficient: true,
      requiredWorkerInstances: 4,
    });
  });

  it("closes effective capacity when the authoritative fal.ai submission gate is blocked", () => {
    const snapshot = createSnapshot();
    snapshot.fal.providerSubmissionsAllowed = false;
    snapshot.fal.submissionBlockReason = "balance_unknown";
    snapshot.fal.isStale = true;

    const result = createGenerationCapacityViewModel(snapshot, 8);

    expect(result).toMatchObject({
      state: "provider_blocked",
      tone: "danger",
      effectiveCapacity: 0,
      bottleneck: "fal",
      workerCapacitySufficient: true,
    });
  });

  it("identifies worker loops as the bottleneck without overstating usable capacity", () => {
    const result = createGenerationCapacityViewModel(createSnapshot(), 2);

    expect(result).toMatchObject({
      state: "degraded",
      tone: "warning",
      effectiveCapacity: 2,
      bottleneck: "workers",
      workerCapacitySufficient: false,
      requiredWorkerInstances: 4,
    });
  });

  it("applies the safe-start profile to a copy and leaves the original draft unchanged", () => {
    const draft = {
      ...generationCapacitySafeStartPreset,
      globalMaxConcurrent: 3,
      imageMaxConcurrent: 2,
      imageProtectedConcurrent: 2,
      videoGuaranteedConcurrent: 1,
      videoMaxConcurrent: 1,
      videoBorrowMaxConcurrent: 0,
      workerLoopsPerInstance: 1,
      falConfiguredConcurrency: 0,
      falReservedConcurrency: 1,
      falBalanceLowThresholdUsd: 100,
      falBalanceCriticalThresholdUsd: 25,
    };

    const result = applyGenerationCapacityPreset(draft);

    expect(result).toEqual(generationCapacitySafeStartPreset);
    expect(result).not.toBe(draft);
    expect(draft).toMatchObject({
      globalMaxConcurrent: 3,
      workerLoopsPerInstance: 1,
      falConfiguredConcurrency: 0,
    });
  });
});
