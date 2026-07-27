"use client";

import { useEffect, useState } from "react";

import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import {
  SUPPORT_INBOX_SEARCH_MAX_LENGTH,
  SUPPORT_MESSAGE_BODY_MAX_LENGTH,
  type AdminSupportConversation,
  type SupportConversationPriority,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
  type SupportInboxQueue,
  type SupportInboxSort,
} from "@/lib/api-client";
import { type Dictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type UseSupportConversationControllerParams = {
  locale: Locale;
  conversationId: string;
  queueStatusFilter?: "all" | SupportConversationStatus;
  initialQueueState?: SupportQueueUrlState;
};

export type SupportReplySessionIdentity = {
  userId?: string | null;
  displayName?: string | null;
  email?: string | null;
};

export type SupportReplyActor = {
  userId: string;
  displayName: string | null;
  email: string | null;
};

export function getSupportReplyActor(
  identity: SupportReplySessionIdentity | null | undefined
): SupportReplyActor | null {
  if (!identity) {
    return null;
  }

  const userId = identity.userId?.trim();
  if (!userId) {
    return null;
  }

  return {
    userId,
    displayName: identity.displayName ?? null,
    email: identity.email ?? null,
  };
}

export function isSupportReplyActorCurrent(
  actor: SupportReplyActor | null | undefined,
  currentIdentity: SupportReplySessionIdentity | null | undefined
): boolean {
  return Boolean(actor && actor.userId === currentIdentity?.userId?.trim());
}

export type SendOptimisticContext = {
  optimisticMessageId?: string;
  optimisticAttachmentObjectUrl?: string;
};

export type ToastState = {
  type: "success" | "error";
  message: string;
};

export type SupportQueueFilter =
  "all" | SupportConversationStatus | "mine" | "unassigned" | "waiting" | "unread";

export type SupportQueueSubFilter = "all" | "unassigned" | "unread";

export type SupportQueueUrlState = {
  subFilter: SupportQueueSubFilter;
  status: "all" | SupportConversationStatus;
  priority: "all" | SupportConversationPriority;
  sort: SupportInboxSort;
  search: string;
  page: number;
};

export type SidePanelTab = "user" | "activity" | "dialog" | "attachments";

export const SUPPORT_INBOX_PAGE_SIZE = 50;
export const SUPPORT_QUEUE_PAGE_MAX = 10_000;
export const SUPPORT_SEARCH_MAX_LENGTH = SUPPORT_INBOX_SEARCH_MAX_LENGTH;
export const SUPPORT_REPLY_MAX_LENGTH = SUPPORT_MESSAGE_BODY_MAX_LENGTH;
export const statusOptions: SupportConversationStatus[] = [
  "New",
  "InProgress",
  "WaitingForUser",
  "Closed",
];
export const supportPollingIntervalMs = 8_000;
export const supportRealtimeHealthyPollingIntervalMs = 60_000;
export const supportInboxStaleTimeMs = supportPollingIntervalMs;
export const supportSubjectContextStaleTimeMs = 30_000;
export const supportConversationMessagesTake = 80;

const supportQueueSubFilters = ["all", "unassigned", "unread"] as const;
const supportQueuePriorities = ["all", "Low", "Normal", "High"] as const;
const supportQueueSorts = ["default", "priority", "waiting", "updated", "created"] as const;

export const DEFAULT_SUPPORT_QUEUE_URL_STATE: SupportQueueUrlState = {
  subFilter: "all",
  status: "all",
  priority: "all",
  sort: "default",
  search: "",
  page: 1,
};

type SupportSearchParamsReader = Pick<URLSearchParams, "get">;

function readSupportQueueOption<const T extends string>(
  value: string | null,
  allowed: readonly T[],
  fallback: T
): T {
  const normalized = value?.trim().toLowerCase();
  if (!normalized) {
    return fallback;
  }

  return allowed.find((item) => item.toLowerCase() === normalized) ?? fallback;
}

function readSupportQueuePage(value: string | null): number {
  const normalized = value?.trim() ?? "";
  if (!/^\d+$/.test(normalized)) {
    return DEFAULT_SUPPORT_QUEUE_URL_STATE.page;
  }

  const parsed = Number(normalized);
  if (!Number.isFinite(parsed)) {
    return SUPPORT_QUEUE_PAGE_MAX;
  }

  return Math.min(SUPPORT_QUEUE_PAGE_MAX, Math.max(1, Math.floor(parsed)));
}

export function readSupportQueueUrlState(
  searchParams: SupportSearchParamsReader
): SupportQueueUrlState {
  const queueValue =
    searchParams.get("queue") ?? searchParams.get("subFilter") ?? searchParams.get("assignment");

  return {
    subFilter: readSupportQueueOption(
      queueValue,
      supportQueueSubFilters,
      DEFAULT_SUPPORT_QUEUE_URL_STATE.subFilter
    ),
    status: readSupportQueueOption(
      searchParams.get("status"),
      ["all", ...statusOptions],
      DEFAULT_SUPPORT_QUEUE_URL_STATE.status
    ),
    priority: readSupportQueueOption(
      searchParams.get("priority"),
      supportQueuePriorities,
      DEFAULT_SUPPORT_QUEUE_URL_STATE.priority
    ),
    sort: readSupportQueueOption(
      searchParams.get("sort"),
      supportQueueSorts,
      DEFAULT_SUPPORT_QUEUE_URL_STATE.sort
    ),
    search: (searchParams.get("search") ?? "").trim().slice(0, SUPPORT_SEARCH_MAX_LENGTH),
    page: readSupportQueuePage(searchParams.get("page")),
  };
}

export function buildSupportQueueSearchParams(
  state: SupportQueueUrlState,
  currentSearch = ""
): string {
  const params = new URLSearchParams(
    currentSearch.startsWith("?") ? currentSearch.slice(1) : currentSearch
  );

  for (const key of [
    "queue",
    "subFilter",
    "assignment",
    "status",
    "priority",
    "sort",
    "search",
    "page",
  ]) {
    params.delete(key);
  }

  if (state.subFilter !== DEFAULT_SUPPORT_QUEUE_URL_STATE.subFilter) {
    params.set("queue", state.subFilter);
  }
  if (state.status !== DEFAULT_SUPPORT_QUEUE_URL_STATE.status) {
    params.set("status", state.status);
  }
  if (state.priority !== DEFAULT_SUPPORT_QUEUE_URL_STATE.priority) {
    params.set("priority", state.priority);
  }
  if (state.sort !== DEFAULT_SUPPORT_QUEUE_URL_STATE.sort) {
    params.set("sort", state.sort);
  }

  const normalizedSearch = state.search.trim().slice(0, SUPPORT_SEARCH_MAX_LENGTH);
  if (normalizedSearch) {
    params.set("search", normalizedSearch);
  }

  const normalizedPage = Math.min(SUPPORT_QUEUE_PAGE_MAX, Math.max(1, Math.floor(state.page)));
  if (normalizedPage !== DEFAULT_SUPPORT_QUEUE_URL_STATE.page) {
    params.set("page", String(normalizedPage));
  }

  return params.toString();
}

export function resolveQueueFilter(filter: SupportQueueFilter): {
  status?: SupportConversationStatus;
  assignment: SupportInboxAssignmentScope;
  queue?: SupportInboxQueue;
} {
  if (filter === "all") {
    return { status: undefined, assignment: "all" };
  }
  if (filter === "waiting") {
    return { status: undefined, assignment: "all", queue: "waiting_for_support" };
  }
  if (filter === "unread") {
    return { status: undefined, assignment: "all", queue: "unread" };
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

export function buildSupportRealtimeToastMessage(locale: Locale): string {
  const copy = getSupportConversationCopy(locale);
  return copy.controller.realtimeMessageFallback;
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

type SupportErrorMessageText = Pick<
  Dictionary,
  | "supportAttachmentRetryRequired"
  | "supportAttachmentRetryUnavailable"
  | "supportAttachmentTooLarge"
  | "supportAttachmentTypeInvalid"
  | "supportMessageTooLong"
  | "supportReplyTargetInvalid"
>;

function getSupportErrorCodes(error: unknown): string[] {
  if (!error || typeof error !== "object") {
    return [];
  }

  const candidate = error as { code?: unknown; validationErrors?: unknown };
  const values = [
    candidate.code,
    ...(Array.isArray(candidate.validationErrors) ? candidate.validationErrors : []),
  ];

  return values
    .filter((value): value is string => typeof value === "string")
    .map((value) => value.trim().toLowerCase())
    .filter((value) => value.startsWith("support."));
}

export function getSupportActionErrorMessage(
  error: unknown,
  text: SupportErrorMessageText
): string | undefined {
  for (const code of getSupportErrorCodes(error)) {
    switch (code) {
      case "support.attachment_file_too_large":
        return text.supportAttachmentTooLarge;
      case "support.attachment_storage_failed":
        return text.supportAttachmentRetryRequired;
      case "support.attachment_retry_not_allowed":
        return text.supportAttachmentRetryUnavailable;
      case "support.message_body_too_long":
        return text.supportMessageTooLong;
      case "support.reply_target_invalid":
        return text.supportReplyTargetInvalid;
      case "support.attachment_invalid_upload":
      case "support.attachment_content_type_not_allowed":
      case "support.attachment_mime_mismatch":
      case "support.attachment_file_required":
      case "support.attachment_file_name_required":
      case "support.attachment_file_name_too_long":
      case "support.attachment_content_type_too_long":
      case "support.attachment_batch_limit_exceeded":
      case "support.message_attachments_count_invalid":
        return text.supportAttachmentTypeInvalid;
    }
  }

  return undefined;
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
  incomingConversation: AdminSupportConversation,
  options?: { replacePagination?: boolean }
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
    hasOlderMessages: options?.replacePagination
      ? incomingConversation.hasOlderMessages
      : currentConversation.hasOlderMessages || incomingConversation.hasOlderMessages,
    oldestLoadedMessageCreatedAtUtc: options?.replacePagination
      ? incomingConversation.oldestLoadedMessageCreatedAtUtc
      : (currentConversation.oldestLoadedMessageCreatedAtUtc ??
        incomingConversation.oldestLoadedMessageCreatedAtUtc),
  };
}

export function rollbackOptimisticSupportMessage(
  conversation: AdminSupportConversation,
  optimisticMessageId: string
): AdminSupportConversation {
  const messages = conversation.messages.filter(
    (message) => message.messageId !== optimisticMessageId
  );

  return messages.length === conversation.messages.length
    ? conversation
    : { ...conversation, messages };
}
