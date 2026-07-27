export type AdminSystemStatus = "healthy" | "degraded" | "unhealthy";

export type AdminSystemStatusCheck = {
  key: string;
  status: AdminSystemStatus;
  summary: string;
  checkedAtUtc: string;
};

export type AdminSystemStatusResponse = {
  overallStatus: AdminSystemStatus;
  generatedAtUtc: string;
  staleAfterSeconds: number;
  checks: AdminSystemStatusCheck[];
};

export type AdminOperationsSourceStatus = AdminSystemStatus | "unknown";

export type AdminOperationsQueueStatus = {
  status: AdminOperationsSourceStatus;
  backlogCount: number;
  deadLetterCount: number;
  oldestItemAgeSeconds?: number | null;
  lastSuccessfulRunAtUtc?: string | null;
};

export type AdminOperationsStatusDto = {
  overallStatus: AdminSystemStatus;
  generatedAtUtc: string;
  cacheDurationSeconds: number;
  staleAfterSeconds: number;
  email: AdminOperationsQueueStatus;
  auditOutbox: AdminOperationsQueueStatus;
  pushOutbox: AdminOperationsQueueStatus;
  generations: {
    status: AdminOperationsSourceStatus;
    queueDepth: number;
    oldestQueuedItemAgeSeconds?: number | null;
  };
  economy: {
    status: AdminOperationsSourceStatus;
    openIncidentCount: number;
    criticalIncidentCount: number;
  };
  workers: {
    status: AdminOperationsSourceStatus;
    lastSuccessfulRunAtUtc?: string | null;
    generationWorkerHeartbeatAtUtc?: string | null;
    generationWorkerHeartbeatAgeSeconds?: number | null;
  };
  unavailableSources: string[];
};
