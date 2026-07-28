export type AdminGenerationCapacityHealth = "healthy" | "degraded" | "critical" | "unknown";
export type AdminFalBalanceStatus = "healthy" | "low" | "critical" | "unknown";
export type AdminFalSubmissionBlockReason =
  "concurrency_unknown" | "concurrency_exhausted" | "balance_unknown" | "balance_critical";
export type AdminGenerationAlertSeverity = "info" | "warning" | "critical";
export type AdminRenderScaleOperationStatus =
  "requested" | "draining" | "scaling" | "verifying" | "completed" | "failed" | "cancelled";

export type AdminGenerationControlSettings = {
  version: number;
  globalMaxConcurrent: number;
  imageMaxConcurrent: number;
  imageProtectedConcurrent: number;
  videoGuaranteedConcurrent: number;
  videoMaxConcurrent: number;
  videoBorrowMaxConcurrent: number;
  workerLoopsPerInstance: number;
  falConfiguredConcurrency: number;
  falReservedConcurrency: number;
  falBalanceLowThresholdUsd: number;
  falBalanceCriticalThresholdUsd: number;
  updatedAtUtc: string;
  updatedByAdminId: string | null;
};

export type AdminGenerationControlStatus = {
  generatedAtUtc: string;
  activeGlobal: number;
  activeImage: number;
  activeVideo: number;
  queuedImage: number;
  queuedVideo: number;
  effectiveImageMaxConcurrent: number;
  borrowedVideo: number;
  isDraining: boolean;
  health: AdminGenerationCapacityHealth;
};

export type AdminFalGenerationCapacity = {
  configuredProvider?: string;
  isEnabled?: boolean;
  billingAdminKeyConfigured?: boolean | null;
  lastErrorCode?: string | null;
  consecutiveFailures?: number;
  lastAttemptSucceeded?: boolean | null;
  configuredConcurrency: number;
  reservedConcurrency: number;
  usableConcurrency: number;
  inflightRequests: number;
  balanceUsd: number | null;
  balanceStatus: AdminFalBalanceStatus;
  checkedAtUtc: string | null;
  lastSuccessAtUtc: string | null;
  isStale: boolean;
  providerSubmissionsAllowed: boolean;
  submissionBlockReason: AdminFalSubmissionBlockReason | null;
};

export type AdminGenerationWorkerState = {
  instanceId: string;
  lastSeenAtUtc: string;
  heartbeatAgeSeconds: number;
  appliedSettingsVersion: number;
  configuredLoops: number;
  isStale: boolean;
  isConfigCurrent: boolean;
  isDraining: boolean;
};

export type AdminGenerationControlAlert = {
  id: string;
  code: string;
  severity: AdminGenerationAlertSeverity;
  title: string;
  message: string;
  activatedAtUtc: string;
  resolvedAtUtc: string | null;
  acknowledgedAtUtc: string | null;
  isActive: boolean;
  isAcknowledged: boolean;
};

export type AdminRenderScaleOperation = {
  operationId: string;
  status: AdminRenderScaleOperationStatus;
  initialInstances: number | null;
  targetInstances: number;
  loopsPerInstance: number;
  reason: string;
  createdAtUtc: string;
  updatedAtUtc: string;
  drainStartedAtUtc: string | null;
  scaleRequestedAtUtc: string | null;
  completedAtUtc: string | null;
  cancelledAtUtc: string | null;
  errorCode: string | null;
  canCancel: boolean;
};

export type AdminGenerationRenderCapacity = {
  isConfigured: boolean;
  serviceId: string | null;
  serviceName: string | null;
  serviceType: string | null;
  plan: string | null;
  region: string | null;
  desiredInstances: number | null;
  activeInstances: number | null;
  autoscalingEnabled: boolean;
  configurationError: string | null;
  operation: AdminRenderScaleOperation | null;
};

export type AdminGenerationControlSnapshot = {
  settings: AdminGenerationControlSettings;
  status: AdminGenerationControlStatus;
  fal: AdminFalGenerationCapacity;
  workers: AdminGenerationWorkerState[];
  render: AdminGenerationRenderCapacity | null;
  alerts: AdminGenerationControlAlert[];
};

export type UpdateAdminGenerationControlCommand = Pick<
  AdminGenerationControlSettings,
  | "globalMaxConcurrent"
  | "imageMaxConcurrent"
  | "imageProtectedConcurrent"
  | "videoGuaranteedConcurrent"
  | "videoMaxConcurrent"
  | "videoBorrowMaxConcurrent"
  | "workerLoopsPerInstance"
  | "falConfiguredConcurrency"
  | "falReservedConcurrency"
  | "falBalanceLowThresholdUsd"
  | "falBalanceCriticalThresholdUsd"
> & {
  expectedVersion: number;
  reason: string;
};

export type RequestAdminRenderScaleCommand = {
  targetInstances: number;
  expectedCurrentInstances: number | null;
  reason: string;
  confirmed: true;
};
