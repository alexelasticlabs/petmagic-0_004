import type {
  AdminFalBalanceStatus,
  AdminFalGenerationCapacity,
  AdminFalSubmissionBlockReason,
  AdminGenerationAlertSeverity,
  AdminGenerationCapacityHealth,
  AdminGenerationControlAlert,
  AdminGenerationControlSettings,
  AdminGenerationControlSnapshot,
  AdminGenerationControlStatus,
  AdminGenerationRenderCapacity,
  AdminGenerationWorkerState,
  AdminRenderScaleOperation,
  AdminRenderScaleOperationStatus,
} from "./api-client.types.generation-control";

type JsonRecord = Record<string, unknown>;

function invalid(path: string): never {
  throw new Error(`Invalid generation control response at ${path}.`);
}

function record(value: unknown, path: string): JsonRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) invalid(path);
  return value as JsonRecord;
}

function string(value: unknown, path: string, allowEmpty = false): string {
  if (typeof value !== "string" || (!allowEmpty && !value.trim())) invalid(path);
  return value;
}

function nullableString(value: unknown, path: string): string | null {
  if (value === null || typeof value === "undefined") return null;
  return string(value, path, true);
}

function number(value: unknown, path: string, options: { integer?: boolean; min?: number } = {}) {
  if (typeof value !== "number" || !Number.isFinite(value)) invalid(path);
  if (options.integer && !Number.isInteger(value)) invalid(path);
  if (typeof options.min === "number" && value < options.min) invalid(path);
  return value;
}

function nullableNumber(value: unknown, path: string): number | null {
  if (value === null || typeof value === "undefined") return null;
  return number(value, path, { min: 0 });
}

function boolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") invalid(path);
  return value;
}

function enumValue<T extends string>(value: unknown, values: readonly T[], path: string): T {
  if (typeof value !== "string" || !values.includes(value as T)) invalid(path);
  return value as T;
}

function nullableEnumValue<T extends string>(
  value: unknown,
  values: readonly T[],
  path: string
): T | null {
  if (value === null) return null;
  return enumValue(value, values, path);
}

function settings(value: unknown): AdminGenerationControlSettings {
  const item = record(value, "settings");
  return {
    version: number(item.version, "settings.version", { integer: true, min: 1 }),
    globalMaxConcurrent: number(item.globalMaxConcurrent, "settings.globalMaxConcurrent", {
      integer: true,
      min: 1,
    }),
    imageMaxConcurrent: number(item.imageMaxConcurrent, "settings.imageMaxConcurrent", {
      integer: true,
      min: 1,
    }),
    imageProtectedConcurrent: number(
      item.imageProtectedConcurrent,
      "settings.imageProtectedConcurrent",
      { integer: true, min: 1 }
    ),
    videoGuaranteedConcurrent: number(
      item.videoGuaranteedConcurrent,
      "settings.videoGuaranteedConcurrent",
      { integer: true, min: 1 }
    ),
    videoMaxConcurrent: number(item.videoMaxConcurrent, "settings.videoMaxConcurrent", {
      integer: true,
      min: 1,
    }),
    videoBorrowMaxConcurrent: number(
      item.videoBorrowMaxConcurrent,
      "settings.videoBorrowMaxConcurrent",
      { integer: true, min: 0 }
    ),
    workerLoopsPerInstance: number(item.workerLoopsPerInstance, "settings.workerLoopsPerInstance", {
      integer: true,
      min: 1,
    }),
    falConfiguredConcurrency: number(
      item.falConfiguredConcurrency,
      "settings.falConfiguredConcurrency",
      { integer: true, min: 0 }
    ),
    falReservedConcurrency: number(item.falReservedConcurrency, "settings.falReservedConcurrency", {
      integer: true,
      min: 0,
    }),
    falBalanceLowThresholdUsd: number(
      item.falBalanceLowThresholdUsd,
      "settings.falBalanceLowThresholdUsd",
      { min: 0 }
    ),
    falBalanceCriticalThresholdUsd: number(
      item.falBalanceCriticalThresholdUsd,
      "settings.falBalanceCriticalThresholdUsd",
      { min: 0 }
    ),
    updatedAtUtc: string(item.updatedAtUtc, "settings.updatedAtUtc"),
    updatedByAdminId: nullableString(item.updatedByAdminId, "settings.updatedByAdminId"),
  };
}

function status(value: unknown): AdminGenerationControlStatus {
  const item = record(value, "status");
  const health = enumValue<AdminGenerationCapacityHealth>(
    item.health,
    ["healthy", "degraded", "critical", "unknown"],
    "status.health"
  );
  return {
    generatedAtUtc: string(item.generatedAtUtc, "status.generatedAtUtc"),
    activeGlobal: number(item.activeGlobal, "status.activeGlobal", { integer: true, min: 0 }),
    activeImage: number(item.activeImage, "status.activeImage", { integer: true, min: 0 }),
    activeVideo: number(item.activeVideo, "status.activeVideo", { integer: true, min: 0 }),
    queuedImage: number(item.queuedImage, "status.queuedImage", { integer: true, min: 0 }),
    queuedVideo: number(item.queuedVideo, "status.queuedVideo", { integer: true, min: 0 }),
    effectiveImageMaxConcurrent: number(
      item.effectiveImageMaxConcurrent,
      "status.effectiveImageMaxConcurrent",
      { integer: true, min: 0 }
    ),
    borrowedVideo: number(item.borrowedVideo, "status.borrowedVideo", { integer: true, min: 0 }),
    isDraining: boolean(item.isDraining, "status.isDraining"),
    health,
  };
}

function fal(value: unknown): AdminFalGenerationCapacity {
  const item = record(value, "fal");
  const configuredConcurrency = number(item.configuredConcurrency, "fal.configuredConcurrency", {
    integer: true,
    min: 0,
  });
  const reservedConcurrency = number(item.reservedConcurrency, "fal.reservedConcurrency", {
    integer: true,
    min: 0,
  });
  const usableConcurrency = number(item.usableConcurrency, "fal.usableConcurrency", {
    integer: true,
    min: 0,
  });
  const inflightRequests = number(item.inflightRequests, "fal.inflightRequests", {
    integer: true,
    min: 0,
  });
  const balanceUsd = nullableNumber(item.balanceUsd, "fal.balanceUsd");
  const balanceStatus = enumValue<AdminFalBalanceStatus>(
    item.balanceStatus,
    ["healthy", "low", "critical", "unknown"],
    "fal.balanceStatus"
  );
  const isStale = boolean(item.isStale, "fal.isStale");
  const hasProviderGate = "providerSubmissionsAllowed" in item;
  const hasBlockReason = "submissionBlockReason" in item;
  if (hasProviderGate !== hasBlockReason) invalid("fal.providerGate");

  let submissionBlockReason: AdminFalSubmissionBlockReason | null;
  let providerSubmissionsAllowed: boolean;
  if (hasProviderGate) {
    submissionBlockReason = nullableEnumValue<AdminFalSubmissionBlockReason>(
      item.submissionBlockReason,
      ["concurrency_unknown", "concurrency_exhausted", "balance_unknown", "balance_critical"],
      "fal.submissionBlockReason"
    );
    providerSubmissionsAllowed = boolean(
      item.providerSubmissionsAllowed,
      "fal.providerSubmissionsAllowed"
    );
    if (providerSubmissionsAllowed === (submissionBlockReason !== null)) {
      invalid("fal.providerGate");
    }
  } else {
    submissionBlockReason =
      configuredConcurrency <= 0
        ? "concurrency_unknown"
        : usableConcurrency <= 0 || inflightRequests >= usableConcurrency
          ? "concurrency_exhausted"
          : isStale || balanceUsd === null || balanceStatus === "unknown"
            ? "balance_unknown"
            : balanceStatus === "critical"
              ? "balance_critical"
              : null;
    providerSubmissionsAllowed = submissionBlockReason === null;
  }

  return {
    configuredConcurrency,
    reservedConcurrency,
    usableConcurrency,
    inflightRequests,
    balanceUsd,
    balanceStatus,
    checkedAtUtc: nullableString(item.checkedAtUtc, "fal.checkedAtUtc"),
    lastSuccessAtUtc: nullableString(item.lastSuccessAtUtc, "fal.lastSuccessAtUtc"),
    isStale,
    providerSubmissionsAllowed,
    submissionBlockReason,
  };
}

function worker(value: unknown, index: number): AdminGenerationWorkerState {
  const path = `workers[${index}]`;
  const item = record(value, path);
  return {
    instanceId: string(item.instanceId, `${path}.instanceId`),
    lastSeenAtUtc: string(item.lastSeenAtUtc, `${path}.lastSeenAtUtc`),
    heartbeatAgeSeconds: number(item.heartbeatAgeSeconds, `${path}.heartbeatAgeSeconds`, {
      min: 0,
    }),
    appliedSettingsVersion: number(item.appliedSettingsVersion, `${path}.appliedSettingsVersion`, {
      integer: true,
      min: 0,
    }),
    configuredLoops: number(item.configuredLoops, `${path}.configuredLoops`, {
      integer: true,
      min: 0,
    }),
    isStale: boolean(item.isStale, `${path}.isStale`),
    isConfigCurrent: boolean(item.isConfigCurrent, `${path}.isConfigCurrent`),
    isDraining: boolean(item.isDraining, `${path}.isDraining`),
  };
}

function alert(value: unknown, index = 0): AdminGenerationControlAlert {
  const path = `alerts[${index}]`;
  const item = record(value, path);
  const severity = enumValue<AdminGenerationAlertSeverity>(
    item.severity,
    ["info", "warning", "critical"],
    `${path}.severity`
  );
  return {
    id: string(item.id, `${path}.id`),
    code: string(item.code, `${path}.code`),
    severity,
    title: string(item.title, `${path}.title`),
    message: string(item.message, `${path}.message`),
    activatedAtUtc: string(item.activatedAtUtc, `${path}.activatedAtUtc`),
    resolvedAtUtc: nullableString(item.resolvedAtUtc, `${path}.resolvedAtUtc`),
    acknowledgedAtUtc: nullableString(item.acknowledgedAtUtc, `${path}.acknowledgedAtUtc`),
    isActive: boolean(item.isActive, `${path}.isActive`),
    isAcknowledged: boolean(item.isAcknowledged, `${path}.isAcknowledged`),
  };
}

function operation(value: unknown, path = "render.operation"): AdminRenderScaleOperation {
  const item = record(value, path);
  const operationStatus = enumValue<AdminRenderScaleOperationStatus>(
    item.status,
    ["requested", "draining", "scaling", "verifying", "completed", "failed", "cancelled"],
    `${path}.status`
  );
  return {
    operationId: string(item.operationId, `${path}.operationId`),
    status: operationStatus,
    initialInstances: nullableNumber(item.initialInstances, `${path}.initialInstances`),
    targetInstances: number(item.targetInstances, `${path}.targetInstances`, {
      integer: true,
      min: 1,
    }),
    loopsPerInstance: number(item.loopsPerInstance, `${path}.loopsPerInstance`, {
      integer: true,
      min: 1,
    }),
    reason: string(item.reason, `${path}.reason`, true),
    createdAtUtc: string(item.createdAtUtc, `${path}.createdAtUtc`),
    updatedAtUtc: string(item.updatedAtUtc, `${path}.updatedAtUtc`),
    drainStartedAtUtc: nullableString(item.drainStartedAtUtc, `${path}.drainStartedAtUtc`),
    scaleRequestedAtUtc: nullableString(item.scaleRequestedAtUtc, `${path}.scaleRequestedAtUtc`),
    completedAtUtc: nullableString(item.completedAtUtc, `${path}.completedAtUtc`),
    cancelledAtUtc: nullableString(item.cancelledAtUtc, `${path}.cancelledAtUtc`),
    errorCode: nullableString(item.errorCode, `${path}.errorCode`),
    canCancel: boolean(item.canCancel, `${path}.canCancel`),
  };
}

function renderCapacity(value: unknown): AdminGenerationRenderCapacity | null {
  if (value === null || typeof value === "undefined") return null;
  const item = record(value, "render");
  return {
    isConfigured: boolean(item.isConfigured, "render.isConfigured"),
    serviceId: nullableString(item.serviceId, "render.serviceId"),
    serviceName: nullableString(item.serviceName, "render.serviceName"),
    serviceType: nullableString(item.serviceType, "render.serviceType"),
    plan: nullableString(item.plan, "render.plan"),
    region: nullableString(item.region, "render.region"),
    desiredInstances: nullableNumber(item.desiredInstances, "render.desiredInstances"),
    activeInstances: nullableNumber(item.activeInstances, "render.activeInstances"),
    autoscalingEnabled: boolean(item.autoscalingEnabled, "render.autoscalingEnabled"),
    configurationError: nullableString(item.configurationError, "render.configurationError"),
    operation:
      item.operation === null || typeof item.operation === "undefined"
        ? null
        : operation(item.operation),
  };
}

export function parseAdminGenerationControlSnapshot(
  value: unknown
): AdminGenerationControlSnapshot {
  const root = record(value, "root");
  if (!Array.isArray(root.workers)) invalid("workers");
  if (!Array.isArray(root.alerts)) invalid("alerts");
  return {
    settings: settings(root.settings),
    status: status(root.status),
    fal: fal(root.fal),
    workers: root.workers.map(worker),
    render: renderCapacity(root.render),
    alerts: root.alerts.map(alert),
  };
}

export function parseAdminGenerationControlAlert(value: unknown): AdminGenerationControlAlert {
  return alert(value);
}

export function parseAdminRenderScaleOperation(value: unknown): AdminRenderScaleOperation {
  return operation(value, "operation");
}
