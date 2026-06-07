import {
  apiRequest,
  cachedGet,
  cachedSupportConversations,
  cachedSupportInbox,
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
export const SUPPORT_MESSAGE_BODY_MAX_LENGTH = 2_000;

function normalizeSupportInboxSearch(value: string | undefined): string | undefined {
  return value?.trim().slice(0, SUPPORT_INBOX_SEARCH_MAX_LENGTH) || undefined;
}

function normalizeSupportMessageBody(value: string | undefined): string {
  return value?.trim().slice(0, SUPPORT_MESSAGE_BODY_MAX_LENGTH) ?? "";
}

export async function fetchSupportInbox(
  status?: SupportConversationStatus,
  assignment: SupportInboxAssignmentScope = "all",
  options?: {
    search?: string;
    page?: number;
    pageSize?: number;
    signal?: AbortSignal;
  }
): Promise<AdminSupportInboxPage> {
  const normalizedPage = normalizePositiveInteger(options?.page, 10_000);
  const normalizedPageSize = normalizePositiveInteger(options?.pageSize, 100);
  const searchParams = new URLSearchParams();
  if (status) {
    searchParams.set("status", status);
  }
  if (assignment !== "all") {
    searchParams.set("assignment", assignment);
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

export async function fetchSupportInboxMetrics(signal?: AbortSignal): Promise<AdminSupportInboxMetrics> {
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
    signal?: AbortSignal;
  }
): Promise<AdminSupportConversation> {
  const encodedConversationId = encodePathSegment(conversationId);
  const normalizedTake = normalizePositiveInteger(options?.take, 100);
  const searchParams = new URLSearchParams();
  if (normalizedTake) {
    searchParams.set("take", String(normalizedTake));
  }

  if (options?.beforeMessageCreatedAtUtc) {
    searchParams.set("beforeMessageCreatedAtUtc", options.beforeMessageCreatedAtUtc);
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
  cachedSupportInbox.clear();
  inflightGetRequests.clear();

  if (conversationId) {
    cachedSupportConversations.delete(`support-conversation:${conversationId}`);
    return;
  }

  cachedSupportConversations.clear();
}

function clearSupportTemplateCaches(): void {
  cachedSupportTemplates.clear();
  inflightGetRequests.delete("support-templates");
}
