import { describe, expect, it } from "vitest";

import {
  parseAdminGenerationControlSnapshot,
  parseAdminRenderScaleOperation,
} from "./api-client.generation-control.parser";

function createSnapshot() {
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
      updatedByAdminId: "admin-1",
    },
    status: {
      generatedAtUtc: "2026-07-28T10:01:00Z",
      activeGlobal: 6,
      activeImage: 5,
      activeVideo: 1,
      queuedImage: 3,
      queuedVideo: 2,
      effectiveImageMaxConcurrent: 6,
      borrowedVideo: 0,
      isDraining: false,
      health: "healthy",
    },
    fal: {
      configuredConcurrency: 10,
      reservedConcurrency: 2,
      usableConcurrency: 8,
      inflightRequests: 6,
      balanceUsd: 20,
      balanceStatus: "healthy",
      checkedAtUtc: "2026-07-28T10:01:00Z",
      lastSuccessAtUtc: "2026-07-28T10:01:00Z",
      isStale: false,
      providerSubmissionsAllowed: true,
      submissionBlockReason: null as string | null,
    },
    workers: [
      {
        instanceId: "worker-a",
        lastSeenAtUtc: "2026-07-28T10:01:00Z",
        heartbeatAgeSeconds: 2,
        appliedSettingsVersion: 3,
        configuredLoops: 2,
        isStale: false,
        isConfigCurrent: true,
        isDraining: false,
      },
    ],
    render: {
      isConfigured: true,
      serviceId: "srv-1",
      serviceName: "petmagic-production-generation-worker",
      serviceType: "background_worker",
      plan: "standard",
      region: "frankfurt",
      desiredInstances: 1,
      activeInstances: 1,
      autoscalingEnabled: false,
      configurationError: null,
      operation: null,
    },
    alerts: [
      {
        id: "alert-1",
        code: "fal_balance_low",
        severity: "warning",
        title: "fal.ai balance is low",
        message: "Add credits before launch.",
        activatedAtUtc: "2026-07-28T10:00:00Z",
        resolvedAtUtc: null,
        acknowledgedAtUtc: null,
        isActive: true,
        isAcknowledged: false,
      },
    ],
  };
}

describe("generation control response parser", () => {
  it("accepts the complete backend snapshot without leaking unknown fields", () => {
    const parsed = parseAdminGenerationControlSnapshot({
      ...createSnapshot(),
      secret: "must-not-propagate",
    });

    expect(parsed.settings.globalMaxConcurrent).toBe(8);
    expect(parsed.fal.usableConcurrency).toBe(8);
    expect(parsed.fal.providerSubmissionsAllowed).toBe(true);
    expect(parsed.fal.submissionBlockReason).toBeNull();
    expect(parsed.render?.serviceName).toBe("petmagic-production-generation-worker");
    expect(parsed.alerts[0]).toMatchObject({ code: "fal_balance_low", isAcknowledged: false });
    expect(parsed).not.toHaveProperty("secret");
  });

  it("accepts an unconfigured fal.ai concurrency limit so an admin can configure it", () => {
    const snapshot = createSnapshot();
    snapshot.settings.falConfiguredConcurrency = 0;
    snapshot.fal.configuredConcurrency = 0;
    snapshot.fal.usableConcurrency = 0;
    snapshot.fal.providerSubmissionsAllowed = false;
    snapshot.fal.submissionBlockReason = "concurrency_unknown";

    const parsed = parseAdminGenerationControlSnapshot(snapshot);

    expect(parsed.settings.falConfiguredConcurrency).toBe(0);
    expect(parsed.fal.configuredConcurrency).toBe(0);
    expect(parsed.fal.providerSubmissionsAllowed).toBe(false);
    expect(parsed.fal.submissionBlockReason).toBe("concurrency_unknown");
  });

  it("derives the gate for a rolling deploy from the legacy fal payload", () => {
    const legacySnapshot = createSnapshot();
    delete (legacySnapshot.fal as Partial<typeof legacySnapshot.fal>).providerSubmissionsAllowed;
    delete (legacySnapshot.fal as Partial<typeof legacySnapshot.fal>).submissionBlockReason;

    const parsed = parseAdminGenerationControlSnapshot(legacySnapshot);

    expect(parsed.fal.providerSubmissionsAllowed).toBe(true);
    expect(parsed.fal.submissionBlockReason).toBeNull();
  });

  it("rejects a partial provider gate and unstable block reasons", () => {
    const partialGate = createSnapshot();
    delete (partialGate.fal as Partial<typeof partialGate.fal>).providerSubmissionsAllowed;
    expect(() => parseAdminGenerationControlSnapshot(partialGate)).toThrow("fal.providerGate");

    const unknownReason = createSnapshot();
    unknownReason.fal.submissionBlockReason = "provider_paused";
    expect(() => parseAdminGenerationControlSnapshot(unknownReason)).toThrow(
      "fal.submissionBlockReason"
    );
  });

  it("rejects malformed nested data instead of rendering an unsafe partial model", () => {
    const snapshot = createSnapshot();
    snapshot.settings.globalMaxConcurrent = Number.NaN;

    expect(() => parseAdminGenerationControlSnapshot(snapshot)).toThrow(
      "settings.globalMaxConcurrent"
    );
  });

  it("rejects unknown health and operation statuses", () => {
    const snapshot = createSnapshot();
    snapshot.status.health = "excellent";
    expect(() => parseAdminGenerationControlSnapshot(snapshot)).toThrow("status.health");

    expect(() =>
      parseAdminRenderScaleOperation({
        operationId: "operation-1",
        status: "charged",
        initialInstances: 1,
        targetInstances: 4,
        loopsPerInstance: 2,
        reason: "Launch",
        createdAtUtc: "2026-07-28T10:00:00Z",
        updatedAtUtc: "2026-07-28T10:00:00Z",
        drainStartedAtUtc: null,
        scaleRequestedAtUtc: null,
        completedAtUtc: null,
        cancelledAtUtc: null,
        errorCode: null,
        canCancel: true,
      })
    ).toThrow("operation.status");
  });
});
