import type { AdminGenerationControlSnapshot } from "./api-client.types.generation-control";
import type { GenerationCapacityMutableSettings } from "./generation-capacity-settings-draft";

export const generationCapacitySafeStartPreset: GenerationCapacityMutableSettings = {
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
};

export type GenerationOperationalState = "provider_blocked" | "draining" | "degraded" | "ready";

export type GenerationCapacityLayer = "petmagic" | "workers" | "fal";

export type GenerationCapacityViewModel = {
  state: GenerationOperationalState;
  tone: "danger" | "warning" | "success";
  effectiveCapacity: number;
  bottleneck: GenerationCapacityLayer;
  workerCapacitySufficient: boolean;
  requiredWorkerInstances: number;
};

export function createGenerationCapacityViewModel(
  snapshot: AdminGenerationControlSnapshot,
  observedWorkerLoops: number
): GenerationCapacityViewModel {
  const providerCapacity = snapshot.fal.providerSubmissionsAllowed
    ? snapshot.fal.usableConcurrency
    : 0;
  const effectiveCapacity = Math.max(
    0,
    Math.min(snapshot.settings.globalMaxConcurrent, observedWorkerLoops, providerCapacity)
  );
  const workerCapacitySufficient = observedWorkerLoops >= snapshot.settings.globalMaxConcurrent;
  const requiredWorkerInstances = Math.ceil(
    snapshot.settings.globalMaxConcurrent / snapshot.settings.workerLoopsPerInstance
  );

  let bottleneck: GenerationCapacityLayer = "petmagic";
  if (!snapshot.fal.providerSubmissionsAllowed || providerCapacity <= effectiveCapacity) {
    bottleneck = "fal";
  } else if (observedWorkerLoops <= effectiveCapacity) {
    bottleneck = "workers";
  }

  if (!snapshot.fal.providerSubmissionsAllowed) {
    return {
      state: "provider_blocked",
      tone: "danger",
      effectiveCapacity,
      bottleneck,
      workerCapacitySufficient,
      requiredWorkerInstances,
    };
  }

  if (snapshot.status.isDraining) {
    return {
      state: "draining",
      tone: "warning",
      effectiveCapacity,
      bottleneck,
      workerCapacitySufficient,
      requiredWorkerInstances,
    };
  }

  if (!workerCapacitySufficient || snapshot.status.health === "degraded") {
    return {
      state: "degraded",
      tone: "warning",
      effectiveCapacity,
      bottleneck,
      workerCapacitySufficient,
      requiredWorkerInstances,
    };
  }

  return {
    state: "ready",
    tone: "success",
    effectiveCapacity,
    bottleneck,
    workerCapacitySufficient,
    requiredWorkerInstances,
  };
}

export function applyGenerationCapacityPreset(
  currentDraft: GenerationCapacityMutableSettings,
  preset: GenerationCapacityMutableSettings = generationCapacitySafeStartPreset
): GenerationCapacityMutableSettings {
  return { ...currentDraft, ...preset };
}
