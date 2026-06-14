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

const FILTER_MAX = 120;

function clean(value?: string): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, FILTER_MAX) : undefined;
}

export function normalizeAdminFeedbackQuery(query: AdminFeedbackQuery = {}): AdminFeedbackQuery {
  return {
    status: query.status && query.status !== "All" ? query.status : undefined,
    priority: query.priority && query.priority !== "All" ? query.priority : undefined,
    type: query.type && query.type !== "All" ? query.type : undefined,
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
    body: JSON.stringify(payload),
  });
}

export async function refundAdminFeedbackCredits(
  feedbackId: string,
  payload: RefundFeedbackCreditsPayload
): Promise<CreditRefund> {
  return apiRequest<CreditRefund>(`/api/admin/feedback/${encodePathSegment(feedbackId)}/refund`, {
    method: "POST",
    body: JSON.stringify(payload),
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
