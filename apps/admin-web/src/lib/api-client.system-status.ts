import { apiRequest } from "./api-client.core";

import type {
  AdminOperationsStatusDto,
  AdminSystemStatusResponse,
} from "./api-client.types.system-status";

export async function fetchAdminSystemStatus(
  signal?: AbortSignal
): Promise<AdminSystemStatusResponse> {
  const response = await apiRequest<unknown>("/api/admin/system/status", {
    method: "GET",
    signal,
  });

  if (!isAdminSystemStatusResponse(response)) {
    throw new Error("Admin system status response contract is invalid.");
  }

  return response;
}

export async function fetchAdminOperationsStatus(
  signal?: AbortSignal
): Promise<AdminOperationsStatusDto> {
  const response = await apiRequest<unknown>("/api/admin/system/operations", {
    method: "GET",
    signal,
  });

  if (!isAdminOperationsStatusDto(response)) {
    throw new Error("Admin operations status response contract is invalid.");
  }

  return response;
}

function isAdminSystemStatusResponse(value: unknown): value is AdminSystemStatusResponse {
  if (!isRecord(value) || !isAdminSystemStatus(value.overallStatus)) {
    return false;
  }

  if (
    typeof value.generatedAtUtc !== "string" ||
    typeof value.staleAfterSeconds !== "number" ||
    !Number.isFinite(value.staleAfterSeconds) ||
    value.staleAfterSeconds <= 0 ||
    !Array.isArray(value.checks) ||
    value.checks.length === 0 ||
    value.checks.length > 20
  ) {
    return false;
  }

  return value.checks.every(
    (check) =>
      isRecord(check) &&
      typeof check.key === "string" &&
      check.key.length > 0 &&
      check.key.length <= 80 &&
      isAdminSystemStatus(check.status) &&
      typeof check.summary === "string" &&
      typeof check.checkedAtUtc === "string"
  );
}

function isAdminSystemStatus(value: unknown): value is AdminSystemStatusResponse["overallStatus"] {
  return value === "healthy" || value === "degraded" || value === "unhealthy";
}

function isAdminOperationsSourceStatus(value: unknown): boolean {
  return isAdminSystemStatus(value) || value === "unknown";
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function isNullableNonNegativeNumber(value: unknown): boolean {
  return value === null || value === undefined || (typeof value === "number" && value >= 0);
}

function isOptionalTimestamp(value: unknown): boolean {
  return value === null || value === undefined || typeof value === "string";
}

function isOperationsQueue(value: unknown): boolean {
  return (
    isRecord(value) &&
    isAdminOperationsSourceStatus(value.status) &&
    isNonNegativeInteger(value.backlogCount) &&
    isNonNegativeInteger(value.deadLetterCount) &&
    isNullableNonNegativeNumber(value.oldestItemAgeSeconds) &&
    isOptionalTimestamp(value.lastSuccessfulRunAtUtc)
  );
}

function isAdminOperationsStatusDto(value: unknown): value is AdminOperationsStatusDto {
  if (
    !isRecord(value) ||
    !isAdminSystemStatus(value.overallStatus) ||
    typeof value.generatedAtUtc !== "string" ||
    !isNonNegativeInteger(value.cacheDurationSeconds) ||
    !isNonNegativeInteger(value.staleAfterSeconds) ||
    !isOperationsQueue(value.email) ||
    !isOperationsQueue(value.auditOutbox) ||
    !isOperationsQueue(value.pushOutbox) ||
    !isRecord(value.generations) ||
    !isAdminOperationsSourceStatus(value.generations.status) ||
    !isNonNegativeInteger(value.generations.queueDepth) ||
    !isNullableNonNegativeNumber(value.generations.oldestQueuedItemAgeSeconds) ||
    !isRecord(value.economy) ||
    !isAdminOperationsSourceStatus(value.economy.status) ||
    !isNonNegativeInteger(value.economy.openIncidentCount) ||
    !isNonNegativeInteger(value.economy.criticalIncidentCount) ||
    !isRecord(value.workers) ||
    !isAdminOperationsSourceStatus(value.workers.status) ||
    !isOptionalTimestamp(value.workers.lastSuccessfulRunAtUtc) ||
    !isOptionalTimestamp(value.workers.generationWorkerHeartbeatAtUtc) ||
    !isNullableNonNegativeNumber(value.workers.generationWorkerHeartbeatAgeSeconds) ||
    !Array.isArray(value.unavailableSources) ||
    value.unavailableSources.length > 4
  ) {
    return false;
  }

  return value.unavailableSources.every(
    (source) => typeof source === "string" && source.length > 0 && source.length <= 32
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
