import {
  apiRequest,
  cachedGet,
  cachedSupportTemplates,
  encodePathSegment,
  inflightGetRequests,
} from "./api-client.core";

import type {
  AdminSupportConversation,
  AdminSupportInboxMetrics,
  AdminSupportInboxPage,
  AdminSupportMessage,
  AdminSupportReplyTemplate,
  SupportConversationPriority,
  SupportConversationStatus,
  SupportInboxAssignmentScope,
} from "./api-client.types";

function normalizePositiveInteger(value: number | undefined, maxValue: number): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? Math.min(Math.floor(value), maxValue)
    : undefined;
}

export const SUPPORT_INBOX_SEARCH_MAX_LENGTH = 120;
export const SUPPORT_CONVERSATION_MESSAGES_MAX_TAKE = 120;
export const SUPPORT_MESSAGE_BODY_MAX_LENGTH = 2_000;
export type SupportInboxSort = "default" | "priority" | "waiting" | "updated" | "created";
export type SupportInboxQueue = "all" | "waiting_for_support";

const SUPPORT_INBOX_STATUSES = ["New", "InProgress", "WaitingForUser", "Closed"] as const;
const SUPPORT_INBOX_ASSIGNMENTS = ["all", "mine", "unassigned"] as const;
const SUPPORT_INBOX_PRIORITIES = ["Low", "Normal", "High"] as const;
const SUPPORT_INBOX_SORTS = ["default", "priority", "waiting", "updated", "created"] as const;
const SUPPORT_INBOX_QUEUES = ["all", "waiting_for_support"] as const;

function normalizeSupportInboxSearch(value: string | undefined): string | undefined {
  return value?.trim().slice(0, SUPPORT_INBOX_SEARCH_MAX_LENGTH) || undefined;
}

function normalizeSupportMessageBody(value: string | undefined): string {
  return value?.trim().slice(0, SUPPORT_MESSAGE_BODY_MAX_LENGTH) ?? "";
}

function normalizeSupportOption<const T extends string>(
  value: string | undefined,
  allowed: readonly T[],
  omitted: readonly string[] = []
): T | undefined {
  const normalized = value?.trim();
  if (!normalized) {
    return undefined;
  }

  const normalizedKey = normalized.toLowerCase();
  if (omitted.some((item) => item.toLowerCase() === normalizedKey)) {
    return undefined;
  }

  return allowed.find((item) => item.toLowerCase() === normalizedKey);
}

export async function fetchSupportInbox(
  status?: SupportConversationStatus | SupportConversationStatus[],
  assignment: SupportInboxAssignmentScope = "all",
  options?: {
    search?: string;
    priority?: SupportConversationPriority;
    sort?: SupportInboxSort;
    queue?: SupportInboxQueue;
    page?: number;
    pageSize?: number;
    signal?: AbortSignal;
  }
): Promise<AdminSupportInboxPage> {
  const normalizedPage = normalizePositiveInteger(options?.page, 10_000);
  const normalizedPageSize = normalizePositiveInteger(options?.pageSize, 100);
  const normalizedAssignment =
    normalizeSupportOption(assignment, SUPPORT_INBOX_ASSIGNMENTS) ?? "all";
  const normalizedPriority = normalizeSupportOption(options?.priority, SUPPORT_INBOX_PRIORITIES);
  const normalizedSort = normalizeSupportOption(options?.sort, SUPPORT_INBOX_SORTS, ["default"]);
  const normalizedQueue = normalizeSupportOption(options?.queue, SUPPORT_INBOX_QUEUES, ["all"]);
  const searchParams = new URLSearchParams();
  const statuses = (Array.isArray(status) ? status : status ? [status] : [])
    .map((statusFilter) => normalizeSupportOption(statusFilter, SUPPORT_INBOX_STATUSES))
    .filter((statusFilter): statusFilter is SupportConversationStatus => Boolean(statusFilter));
  for (const statusFilter of statuses) {
    searchParams.append("status", statusFilter);
  }
  if (normalizedAssignment !== "all") {
    searchParams.set("assignment", normalizedAssignment);
  }
  if (normalizedPriority) {
    searchParams.set("priority", normalizedPriority);
  }
  if (normalizedSort) {
    searchParams.set("sort", normalizedSort);
  }
  if (normalizedQueue) {
    searchParams.set("queue", normalizedQueue);
  }
  const search = normalizeSupportInboxSearch(options?.search);
  if (search) {
    searchParams.set("search", search);
  }
  if (normalizedPage) {
    searchParams.set("page", String(normalizedPage));
  }
  if (normalizedPageSize) {
    searchParams.set("pageSize", String(normalizedPageSize));
  }

  const query = searchParams.size > 0 ? `?${searchParams.toString()}` : "";

  return apiRequest<AdminSupportInboxPage>(`/api/admin/support/tickets${query}`, {
    method: "GET",
    signal: options?.signal,
  });
}

export async function fetchSupportInboxMetrics(
  signal?: AbortSignal
): Promise<AdminSupportInboxMetrics> {
  return apiRequest<AdminSupportInboxMetrics>("/api/admin/support/tickets/metrics", {
    method: "GET",
    signal,
  });
}

export async function fetchSupportConversation(
  conversationId: string,
  options?: {
    take?: number;
    beforeMessageCreatedAtUtc?: string | null;
    beforeMessageId?: string | null;
    signal?: AbortSignal;
  }
): Promise<AdminSupportConversation> {
  const encodedConversationId = encodePathSegment(conversationId);
  const normalizedTake = normalizePositiveInteger(
    options?.take,
    SUPPORT_CONVERSATION_MESSAGES_MAX_TAKE
  );
  const searchParams = new URLSearchParams();
  if (normalizedTake) {
    searchParams.set("take", String(normalizedTake));
  }

  if (options?.beforeMessageCreatedAtUtc) {
    searchParams.set("beforeMessageCreatedAtUtc", options.beforeMessageCreatedAtUtc);
  }

  if (options?.beforeMessageId) {
    searchParams.set("beforeMessageId", options.beforeMessageId);
  }

  const query = searchParams.size > 0 ? `?${searchParams.toString()}` : "";

  return apiRequest<AdminSupportConversation>(
    `/api/admin/support/tickets/${encodedConversationId}${query}`,
    {
      method: "GET",
      signal: options?.signal,
    }
  );
}

export async function sendSupportMessage(
  conversationId: string,
  body: string,
  replyToMessageId?: string | null
): Promise<AdminSupportMessage> {
  const encodedConversationId = encodePathSegment(conversationId);
  const normalizedBody = normalizeSupportMessageBody(body);
  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/tickets/${encodedConversationId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({
        body: normalizedBody,
        ...(replyToMessageId?.trim() ? { replyToMessageId: replyToMessageId.trim() } : {}),
      }),
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function sendSupportAttachment(
  conversationId: string,
  file: File,
  body?: string,
  replyToMessageId?: string | null
): Promise<AdminSupportMessage> {
  const encodedConversationId = encodePathSegment(conversationId);
  const formData = new FormData();
  const normalizedBody = normalizeSupportMessageBody(body);
  if (normalizedBody) {
    formData.append("body", normalizedBody);
  }
  if (replyToMessageId?.trim()) {
    formData.append("replyToMessageId", replyToMessageId.trim());
  }

  formData.append("file", file);

  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/tickets/${encodedConversationId}/attachments`,
    {
      method: "POST",
      body: formData,
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function markSupportConversationRead(conversationId: string): Promise<void> {
  const encodedConversationId = encodePathSegment(conversationId);
  await apiRequest<void>(`/api/admin/support/tickets/${encodedConversationId}/read`, {
    method: "POST",
  });

  clearSupportCaches(conversationId);
}

export async function updateSupportConversationStatus(
  conversationId: string,
  status: SupportConversationStatus
): Promise<AdminSupportConversation> {
  const encodedConversationId = encodePathSegment(conversationId);
  const actionPath =
    status === "WaitingForUser"
      ? "mark-waiting-for-user"
      : status === "InProgress"
        ? "mark-in-progress"
        : status === "Closed"
          ? "close"
          : "mark-in-progress";
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/tickets/${encodedConversationId}/${actionPath}`,
    { method: "POST" }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function assignSupportConversation(
  conversationId: string,
  assignedAdminId?: string | null
): Promise<AdminSupportConversation> {
  const encodedConversationId = encodePathSegment(conversationId);
  const conversation = await apiRequest<AdminSupportConversation>(
    assignedAdminId
      ? `/api/admin/support/tickets/${encodedConversationId}/assign-to-me`
      : `/api/admin/support/tickets/${encodedConversationId}/unassign`,
    { method: "POST" }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function updateSupportConversationMetadata(
  conversationId: string,
  payload: {
    priority: SupportConversationPriority;
    tags: string[];
  }
): Promise<AdminSupportConversation> {
  const encodedConversationId = encodePathSegment(conversationId);
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/tickets/${encodedConversationId}/metadata`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function fetchSupportReplyTemplates(
  signal?: AbortSignal
): Promise<AdminSupportReplyTemplate[]> {
  return cachedGet(
    "support-templates",
    cachedSupportTemplates,
    () =>
      apiRequest<AdminSupportReplyTemplate[]>("/api/admin/support/templates", {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function createSupportReplyTemplate(payload: {
  title: string;
  body: string;
  isEnabled: boolean;
  sortOrder: number;
}): Promise<AdminSupportReplyTemplate> {
  const template = await apiRequest<AdminSupportReplyTemplate>("/api/admin/support/templates", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  clearSupportTemplateCaches();
  return template;
}

export async function updateSupportReplyTemplate(
  templateId: string,
  payload: {
    title: string;
    body: string;
    isEnabled: boolean;
    sortOrder: number;
  }
): Promise<AdminSupportReplyTemplate> {
  const encodedTemplateId = encodePathSegment(templateId);
  const template = await apiRequest<AdminSupportReplyTemplate>(
    `/api/admin/support/templates/${encodedTemplateId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );

  clearSupportTemplateCaches();
  return template;
}

export async function deleteSupportReplyTemplate(templateId: string): Promise<void> {
  const encodedTemplateId = encodePathSegment(templateId);
  await apiRequest<void>(`/api/admin/support/templates/${encodedTemplateId}`, {
    method: "DELETE",
  });

  clearSupportTemplateCaches();
}

function clearSupportCaches(conversationId?: string): void {
  void conversationId;
}

function clearSupportTemplateCaches(): void {
  cachedSupportTemplates.clear();
  inflightGetRequests.delete("support-templates");
}
