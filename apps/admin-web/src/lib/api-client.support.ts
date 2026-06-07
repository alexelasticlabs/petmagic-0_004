import {
  apiRequest,
  cachedGet,
  cachedSupportConversations,
  cachedSupportInbox,
  cachedSupportTemplates,
  inflightGetRequests,
} from "./api-client.core";

import type {
  AdminSupportConversation,
  AdminSupportConversationSummary,
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

export async function fetchSupportInbox(
  status?: SupportConversationStatus,
  assignment: SupportInboxAssignmentScope = "all",
  options?: {
    search?: string;
    page?: number;
    pageSize?: number;
    signal?: AbortSignal;
  }
): Promise<AdminSupportConversationSummary[]> {
  const normalizedPage = normalizePositiveInteger(options?.page, 10_000);
  const normalizedPageSize = normalizePositiveInteger(options?.pageSize, 100);
  const searchParams = new URLSearchParams();
  if (status) {
    searchParams.set("status", status);
  }
  if (assignment !== "all") {
    searchParams.set("assignment", assignment);
  }
  const search = options?.search?.trim();
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

  return apiRequest<AdminSupportConversationSummary[]>(`/api/admin/support/tickets${query}`, {
    method: "GET",
    signal: options?.signal,
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
    `/api/admin/support/tickets/${conversationId}${query}`,
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
  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/tickets/${conversationId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({
        body,
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
  const formData = new FormData();
  const trimmedBody = body?.trim();
  if (trimmedBody) {
    formData.append("body", trimmedBody);
  }
  if (replyToMessageId?.trim()) {
    formData.append("replyToMessageId", replyToMessageId.trim());
  }

  formData.append("file", file);

  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/tickets/${conversationId}/attachments`,
    {
      method: "POST",
      body: formData,
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function markSupportConversationRead(conversationId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/support/tickets/${conversationId}/read`, {
    method: "POST",
  });

  clearSupportCaches(conversationId);
}

export async function updateSupportConversationStatus(
  conversationId: string,
  status: SupportConversationStatus
): Promise<AdminSupportConversation> {
  const actionPath =
    status === "WaitingForUser"
      ? "mark-waiting-for-user"
      : status === "InProgress"
        ? "mark-in-progress"
        : status === "Closed"
          ? "close"
          : "mark-in-progress";
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/tickets/${conversationId}/${actionPath}`,
    { method: "POST" }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function assignSupportConversation(
  conversationId: string,
  assignedAdminId?: string | null
): Promise<AdminSupportConversation> {
  const conversation = await apiRequest<AdminSupportConversation>(
    assignedAdminId
      ? `/api/admin/support/tickets/${conversationId}/assign-to-me`
      : `/api/admin/support/tickets/${conversationId}/unassign`,
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
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/tickets/${conversationId}/metadata`,
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
  const template = await apiRequest<AdminSupportReplyTemplate>(
    `/api/admin/support/templates/${templateId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );

  clearSupportTemplateCaches();
  return template;
}

export async function deleteSupportReplyTemplate(templateId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/support/templates/${templateId}`, {
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
