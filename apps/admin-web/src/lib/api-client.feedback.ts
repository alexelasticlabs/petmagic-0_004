import { apiRequest, encodePathSegment } from "./api-client.core";

import type {
  AdminFeedbackDetails,
  AdminFeedbackPage,
  AdminFeedbackQuery,
  CreditRefund,
  RefundFeedbackCreditsPayload,
  TemplateFeedbackSummary,
  UpdateFeedbackAdminPayload,
} from "./api-client.types";

export const ADMIN_FEEDBACK_FILTER_MAX_LENGTH = 120;
export const ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH = 2000;
export const ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH = 240;

const ADMIN_FEEDBACK_STATUSES = ["New", "InReview", "Resolved", "Dismissed"] as const;
const ADMIN_FEEDBACK_PRIORITIES = ["Low", "Medium", "High", "Critical"] as const;
const ADMIN_FEEDBACK_TYPES = [
  "GenerationResult",
  "GenerationFailure",
  "BugReport",
  "FeatureRequest",
  "PaymentIssue",
  "General",
] as const;

function clean(value?: string): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, ADMIN_FEEDBACK_FILTER_MAX_LENGTH) : undefined;
}

function cleanAllowed<const T extends string>(value: string | undefined, allowed: readonly T[]): T | undefined {
  const cleaned = clean(value);
  return cleaned && allowed.includes(cleaned as T) ? (cleaned as T) : undefined;
}

function normalizeAdminFeedbackUpdatePayload(
  payload: UpdateFeedbackAdminPayload
): UpdateFeedbackAdminPayload {
  return {
    ...payload,
    adminNote:
      typeof payload.adminNote === "string"
        ? payload.adminNote.slice(0, ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH)
        : payload.adminNote,
  };
}

function normalizeFeedbackRefundPayload(
  payload: RefundFeedbackCreditsPayload
): RefundFeedbackCreditsPayload {
  return {
    ...payload,
    reason:
      typeof payload.reason === "string"
        ? payload.reason.trim().slice(0, ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH) || undefined
        : payload.reason,
  };
}

export function normalizeAdminFeedbackQuery(query: AdminFeedbackQuery = {}): AdminFeedbackQuery {
  return {
    status: query.status === "All" ? undefined : cleanAllowed(query.status, ADMIN_FEEDBACK_STATUSES),
    priority:
      query.priority === "All" ? undefined : cleanAllowed(query.priority, ADMIN_FEEDBACK_PRIORITIES),
    type: query.type === "All" ? undefined : cleanAllowed(query.type, ADMIN_FEEDBACK_TYPES),
    category: clean(query.category),
    generationId: clean(query.generationId),
    templateId: clean(query.templateId),
    platform: clean(query.platform),
    fromUtc: clean(query.fromUtc),
    toUtc: clean(query.toUtc),
    userId: clean(query.userId),
    skip: typeof query.skip === "number" ? Math.max(0, Math.floor(query.skip)) : undefined,
    take:
      typeof query.take === "number" && Number.isFinite(query.take)
        ? Math.min(100, Math.max(1, Math.floor(query.take)))
        : undefined,
  };
}

export async function fetchAdminFeedback(
  query: AdminFeedbackQuery = {},
  signal?: AbortSignal
): Promise<AdminFeedbackPage> {
  const normalized = normalizeAdminFeedbackQuery(query);
  const search = new URLSearchParams();
  if (normalized.status) search.set("status", normalized.status);
  if (normalized.priority) search.set("priority", normalized.priority);
  if (normalized.type) search.set("type", normalized.type);
  if (normalized.category) search.set("category", normalized.category);
  if (normalized.generationId) search.set("generationId", normalized.generationId);
  if (normalized.templateId) search.set("templateId", normalized.templateId);
  if (normalized.platform) search.set("platform", normalized.platform);
  if (normalized.fromUtc) search.set("fromUtc", normalized.fromUtc);
  if (normalized.toUtc) search.set("toUtc", normalized.toUtc);
  if (normalized.userId) search.set("userId", normalized.userId);
  if (normalized.skip !== undefined) search.set("skip", String(normalized.skip));
  if (normalized.take !== undefined) search.set("take", String(normalized.take));
  const queryString = search.size ? `?${search.toString()}` : "";

  return apiRequest<AdminFeedbackPage>(`/api/admin/feedback/${queryString}`, {
    method: "GET",
    signal,
  });
}

export async function fetchAdminFeedbackDetails(
  feedbackId: string,
  signal?: AbortSignal
): Promise<AdminFeedbackDetails> {
  return apiRequest<AdminFeedbackDetails>(`/api/admin/feedback/${encodePathSegment(feedbackId)}`, {
    method: "GET",
    signal,
  });
}

export async function updateAdminFeedback(
  feedbackId: string,
  payload: UpdateFeedbackAdminPayload
): Promise<AdminFeedbackDetails> {
  return apiRequest<AdminFeedbackDetails>(`/api/admin/feedback/${encodePathSegment(feedbackId)}`, {
    method: "PUT",
    body: JSON.stringify(normalizeAdminFeedbackUpdatePayload(payload)),
  });
}

export async function refundAdminFeedbackCredits(
  feedbackId: string,
  payload: RefundFeedbackCreditsPayload
): Promise<CreditRefund> {
  return apiRequest<CreditRefund>(`/api/admin/feedback/${encodePathSegment(feedbackId)}/refund`, {
    method: "POST",
    body: JSON.stringify(normalizeFeedbackRefundPayload(payload)),
  });
}

export async function fetchAdminTemplateFeedbackSummary(
  templateId: string,
  signal?: AbortSignal
): Promise<TemplateFeedbackSummary> {
  return apiRequest<TemplateFeedbackSummary>(
    `/api/admin/templates/${encodePathSegment(templateId)}/feedback-summary`,
    { method: "GET", signal }
  );
}
