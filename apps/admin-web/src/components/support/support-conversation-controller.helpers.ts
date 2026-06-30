"use client";

import { useEffect, useState } from "react";

import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import {
  SUPPORT_INBOX_SEARCH_MAX_LENGTH,
  SUPPORT_MESSAGE_BODY_MAX_LENGTH,
  type AdminSupportConversation,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type UseSupportConversationControllerParams = {
  locale: Locale;
  conversationId: string;
  queueStatusFilter?: "all" | SupportConversationStatus;
};

export type SendOptimisticContext = {
  previousConversation?: AdminSupportConversation;
  optimisticMessageId?: string;
  optimisticAttachmentObjectUrl?: string;
};

export type ToastState = {
  type: "success" | "error";
  message: string;
};

export type SupportQueueFilter = "all" | SupportConversationStatus | "mine" | "unassigned";

export type SidePanelTab = "user" | "activity" | "dialog" | "attachments";

export const SUPPORT_INBOX_PAGE_SIZE = 50;
export const SUPPORT_SEARCH_MAX_LENGTH = SUPPORT_INBOX_SEARCH_MAX_LENGTH;
export const SUPPORT_REPLY_MAX_LENGTH = SUPPORT_MESSAGE_BODY_MAX_LENGTH;
export const statusOptions: SupportConversationStatus[] = [
  "New",
  "InProgress",
  "WaitingForUser",
  "Closed",
];
export const supportPollingIntervalMs = 8_000;
export const supportInboxStaleTimeMs = supportPollingIntervalMs;
export const supportSubjectContextStaleTimeMs = 30_000;
export const supportConversationMessagesTake = 80;

export function resolveQueueFilter(filter: SupportQueueFilter): {
  status?: SupportConversationStatus;
  assignment: SupportInboxAssignmentScope;
} {
  if (filter === "all") {
    return { status: undefined, assignment: "all" };
  }
  if (filter === "mine") {
    return { status: undefined, assignment: "mine" };
  }
  if (filter === "unassigned") {
    return { status: undefined, assignment: "unassigned" };
  }
  return { status: filter, assignment: "all" };
}

export function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

export function buildSupportRealtimeToastMessage(
  event: { lastMessagePreview?: string | null },
  locale: Locale
): string {
  const copy = getSupportConversationCopy(locale);
  const fallback = copy.controller.realtimeMessageFallback;
  const preview = formatSupportMessagePreview(event.lastMessagePreview, "");
  if (!preview) {
    return fallback;
  }

  return copy.controller.realtimeMessageWithPreview(preview);
}

export function isUserSupportMessageEvent(event: {
  lastMessageSenderType?: string | null;
  adminUnreadCount?: number;
}) {
  return (
    (event.adminUnreadCount ?? 0) > 0 &&
    (event.lastMessageSenderType?.toLowerCase() === "user" || !event.lastMessageSenderType)
  );
}

export function formatSupportControllerLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

export function getSupportControllerErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function isNotFoundError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }

  if (!("status" in error)) {
    return false;
  }

  return (error as { status?: number }).status === 404;
}

export function normalizeSupportTag(value: string): string {
  return value.trim().replace(/\s+/g, " ").slice(0, 40);
}

export function mergeSupportConversationMessages(
  currentConversation: AdminSupportConversation,
  incomingConversation: AdminSupportConversation
): AdminSupportConversation {
  const mergedById = new Map<string, AdminSupportConversation["messages"][number]>();

  for (const message of currentConversation.messages) {
    mergedById.set(message.messageId, message);
  }

  for (const message of incomingConversation.messages) {
    mergedById.set(message.messageId, message);
  }

  const mergedMessages = [...mergedById.values()].sort((left, right) =>
    left.createdAtUtc.localeCompare(right.createdAtUtc)
  );

  return {
    ...incomingConversation,
    messages: mergedMessages,
    hasOlderMessages: currentConversation.hasOlderMessages || incomingConversation.hasOlderMessages,
    oldestLoadedMessageCreatedAtUtc:
      currentConversation.oldestLoadedMessageCreatedAtUtc ??
      incomingConversation.oldestLoadedMessageCreatedAtUtc,
  };
}
