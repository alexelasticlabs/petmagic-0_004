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
  SupportConversationStatus,
  SupportInboxAssignmentScope,
} from "./api-client.types";

export async function fetchSupportInbox(
  status?: SupportConversationStatus,
  assignment: SupportInboxAssignmentScope = "all"
): Promise<AdminSupportConversationSummary[]> {
  const cacheKey = `support-inbox:${status ?? "all"}:${assignment}`;
  const searchParams = new URLSearchParams();
  if (status) {
    searchParams.set("status", status);
  }
  if (assignment !== "all") {
    searchParams.set("assignment", assignment);
  }

  const query = searchParams.size > 0 ? `?${searchParams.toString()}` : "";

  return cachedGet(cacheKey, cachedSupportInbox, () =>
    apiRequest<AdminSupportConversationSummary[]>(`/api/admin/support/conversations${query}`, {
      method: "GET",
    })
  );
}

export async function fetchSupportConversation(
  conversationId: string
): Promise<AdminSupportConversation> {
  return cachedGet(`support-conversation:${conversationId}`, cachedSupportConversations, () =>
    apiRequest<AdminSupportConversation>(`/api/admin/support/conversations/${conversationId}`, {
      method: "GET",
    })
  );
}

export async function sendSupportMessage(
  conversationId: string,
  body: string
): Promise<AdminSupportMessage> {
  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/conversations/${conversationId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({ body }),
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function sendSupportAttachment(
  conversationId: string,
  file: File,
  body?: string
): Promise<AdminSupportMessage> {
  const formData = new FormData();
  const trimmedBody = body?.trim();
  if (trimmedBody) {
    formData.append("body", trimmedBody);
  }

  formData.append("file", file);

  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/conversations/${conversationId}/attachments`,
    {
      method: "POST",
      body: formData,
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function markSupportConversationRead(conversationId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/support/conversations/${conversationId}/read`, {
    method: "POST",
  });

  clearSupportCaches(conversationId);
}

export async function updateSupportConversationStatus(
  conversationId: string,
  status: SupportConversationStatus
): Promise<AdminSupportConversation> {
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/conversations/${conversationId}/status`,
    {
      method: "PUT",
      body: JSON.stringify({ status }),
    }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function assignSupportConversation(
  conversationId: string,
  assignedAdminId?: string | null
): Promise<AdminSupportConversation> {
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/conversations/${conversationId}/assignment`,
    {
      method: "PUT",
      body: JSON.stringify({ assignedAdminId: assignedAdminId ?? null }),
    }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function fetchSupportReplyTemplates(): Promise<AdminSupportReplyTemplate[]> {
  return cachedGet("support-templates", cachedSupportTemplates, () =>
    apiRequest<AdminSupportReplyTemplate[]>("/api/admin/support/templates", { method: "GET" })
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
