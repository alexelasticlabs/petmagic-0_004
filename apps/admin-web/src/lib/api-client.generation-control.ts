import { apiRequest, encodePathSegment } from "./api-client.core";
import {
  parseAdminGenerationControlAlert,
  parseAdminGenerationControlSnapshot,
  parseAdminRenderScaleOperation,
} from "./api-client.generation-control.parser";

import type {
  AdminGenerationControlAlert,
  AdminGenerationControlSnapshot,
  AdminRenderScaleOperation,
  RequestAdminRenderScaleCommand,
  UpdateAdminGenerationControlCommand,
} from "./api-client.types.generation-control";

const generationControlPath = "/api/admin/templates/generation-control";

export async function fetchAdminGenerationControl(
  signal?: AbortSignal
): Promise<AdminGenerationControlSnapshot> {
  const response = await apiRequest<unknown>(generationControlPath, { method: "GET", signal });
  return parseAdminGenerationControlSnapshot(response);
}

export async function updateAdminGenerationControl(
  command: UpdateAdminGenerationControlCommand
): Promise<AdminGenerationControlSnapshot> {
  const response = await apiRequest<unknown>(generationControlPath, {
    method: "PUT",
    body: JSON.stringify(command),
  });
  return parseAdminGenerationControlSnapshot(response);
}

export async function refreshAdminFalProviderBalance(): Promise<AdminGenerationControlSnapshot> {
  const response = await apiRequest<unknown>(`${generationControlPath}/provider/refresh`, {
    method: "POST",
  });
  return parseAdminGenerationControlSnapshot(response);
}

export async function acknowledgeAdminGenerationAlert(
  alertId: string
): Promise<AdminGenerationControlAlert> {
  const response = await apiRequest<unknown>(
    `${generationControlPath}/alerts/${encodePathSegment(alertId)}/acknowledge`,
    { method: "POST" }
  );
  return parseAdminGenerationControlAlert(response);
}

export async function requestAdminGenerationRenderScale(
  command: RequestAdminRenderScaleCommand,
  idempotencyKey: string
): Promise<AdminRenderScaleOperation> {
  const response = await apiRequest<unknown>(`${generationControlPath}/render/scale`, {
    method: "POST",
    headers: { "Idempotency-Key": idempotencyKey },
    body: JSON.stringify(command),
  });
  return parseAdminRenderScaleOperation(response);
}

export async function fetchAdminGenerationRenderScaleOperation(
  operationId: string,
  signal?: AbortSignal
): Promise<AdminRenderScaleOperation> {
  const response = await apiRequest<unknown>(
    `${generationControlPath}/render/operations/${encodePathSegment(operationId)}`,
    { method: "GET", signal }
  );
  return parseAdminRenderScaleOperation(response);
}

export async function cancelAdminGenerationRenderScaleOperation(
  operationId: string
): Promise<AdminRenderScaleOperation> {
  const response = await apiRequest<unknown>(
    `${generationControlPath}/render/operations/${encodePathSegment(operationId)}/cancel`,
    { method: "POST" }
  );
  return parseAdminRenderScaleOperation(response);
}
