"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { useAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  buildActivityTimeline,
  buildConversationTimeline,
  formatSafeSupportDisplay,
  formatAccountAgeFact,
  formatCountFact,
  getConversationSla,
  sortSupportQueueItems,
  type SupportTimelineItem,
} from "@/components/support/support-conversation-helpers";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { getAvailableStatusActions } from "@/components/support/support-status-helpers";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignSupportConversation,
  fetchAdminEconomyPurchases,
  fetchAdminEconomyUserSubscriptionSummary,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  fetchSupportConversation,
  fetchSupportInbox,
  fetchSupportInboxMetrics,
  markSupportConversationRead,
  sendSupportAttachment,
  sendSupportMessage,
  SUPPORT_INBOX_SEARCH_MAX_LENGTH,
  SUPPORT_MESSAGE_BODY_MAX_LENGTH,
  updateSupportConversationMetadata,
  updateSupportConversationStatus,
  useAuthSession,
  type AdminEconomyPurchase,
  type AdminEconomyUserSubscriptionSummary,
  type AdminSupportConversation,
  type AdminSupportConversationSummary,
  type AdminSupportInboxPage,
  type AdminSupportInboxMetrics,
  type AdminUserAnalytics,
  type AdminUserDetail,
  type SupportConversationPriority,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";
import { maskEmail } from "@/lib/sensitive-display";
import { useSupportRealtime } from "@/lib/support-realtime";

type UseSupportConversationControllerParams = {
  locale: Locale;
  conversationId: string;
  queueStatusFilter?: "all" | SupportConversationStatus;
};

type SendOptimisticContext = {
  previousConversation?: AdminSupportConversation;
  optimisticMessageId?: string;
  optimisticAttachmentObjectUrl?: string;
};

export type ToastState = {
  type: "success" | "error";
  message: string;
};

export type SupportQueueFilter = "all" | SupportConversationStatus | "mine" | "unassigned";

const SUPPORT_INBOX_PAGE_SIZE = 50;

function resolveQueueFilter(filter: SupportQueueFilter): {
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

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function buildSupportRealtimeToastMessage(
  event: { lastMessagePreview?: string | null },
  locale: Locale
): string {
  const fallback = locale === "ru" ? "Новое сообщение в поддержке" : "New support message";
  const preview = formatSupportMessagePreview(event.lastMessagePreview, "");
  if (!preview) {
    return fallback;
  }

  return locale === "ru" ? `Новое сообщение: ${preview}` : `New support message: ${preview}`;
}

function isUserSupportMessageEvent(event: {
  lastMessageSenderType?: string | null;
  adminUnreadCount?: number;
}) {
  return (
    (event.adminUnreadCount ?? 0) > 0 &&
    (event.lastMessageSenderType?.toLowerCase() === "user" || !event.lastMessageSenderType)
  );
}

function isNotFoundError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }

  if (!("status" in error)) {
    return false;
  }

  return (error as { status?: number }).status === 404;
}

export type SidePanelTab = "user" | "activity" | "dialog" | "attachments";

function normalizeSupportTag(value: string): string {
  return value.trim().replace(/\s+/g, " ").slice(0, 40);
}

export const statusOptions: SupportConversationStatus[] = [
  "New",
  "InProgress",
  "WaitingForUser",
  "Closed",
];

export const SUPPORT_SEARCH_MAX_LENGTH = SUPPORT_INBOX_SEARCH_MAX_LENGTH;
export const SUPPORT_REPLY_MAX_LENGTH = SUPPORT_MESSAGE_BODY_MAX_LENGTH;

const supportPollingIntervalMs = 8_000;
const supportConversationMessagesTake = 80;

function mergeSupportConversationMessages(
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

export function useSupportConversationController({
  locale,
  conversationId,
  queueStatusFilter = "all",
}: UseSupportConversationControllerParams) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const { addNotification } = useAdminNotifications();
  const sessionUserRoles = session?.user.roles ?? [];
  const canManageSupportWorkspace =
    sessionUserRoles.includes("Admin") || sessionUserRoles.includes("Moderator");
  const supportActionsForbidden =
    locale === "ru"
      ? "Действия поддержки доступны только Admin или Moderator."
      : "Support actions are available only to Admin or Moderator.";
  const [queueFilter, setQueueFilter] = useState<SupportQueueFilter>("all");
  const [queuePage, setQueuePage] = useState(1);
  const [searchQuery, setRawSearchQuery] = useState("");
  const debouncedSearchQuery = useDebouncedValue(searchQuery.trim(), 350);
  const [reply, setReply] = useState("");
  const [replyToMessageId, setReplyToMessageId] = useState<string | null>(null);
  const [replyToPreview, setReplyToPreview] = useState<string | null>(null);
  const [activeSidePanelTab, setActiveSidePanelTab] = useState<SidePanelTab>("user");
  const [isSidePanelOpen, setIsSidePanelOpen] = useState(
    () => typeof window !== "undefined" && window.matchMedia("(min-width: 1321px)").matches
  );
  const [toast, setToast] = useState<ToastState | null>(null);
  const [selectedAttachment, setSelectedAttachment] = useState<File | null>(null);
  const [isSendReplyInFlight, setIsSendReplyInFlight] = useState(false);
  const attachmentInputRef = useRef<HTMLInputElement | null>(null);
  const sendReplyInFlightRef = useRef(false);
  const markReadRequestRef = useRef<Promise<void> | null>(null);
  const markReadDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastRealtimeToastRef = useRef<string | null>(null);
  const messagesViewportVisibleRef = useRef(false);
  const lastConversationRealtimeFetchRef = useRef(0);
  const loadOlderAbortControllerRef = useRef<AbortController | null>(null);
  const optimisticAttachmentObjectUrlsRef = useRef(new Map<string, string>());
  const optimisticMessageCounterRef = useRef(0);

  const resetSelectedAttachment = useCallback(() => {
    setSelectedAttachment(null);
    if (attachmentInputRef.current) {
      attachmentInputRef.current.value = "";
    }
  }, [setSelectedAttachment]);

  const refreshConversationData = useCallback(async () => {
    await Promise.allSettled([
      queryClient.invalidateQueries({
        queryKey: adminQueryKeys.supportConversation(conversationId),
      }),
      queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot }),
    ]);
  }, [conversationId, queryClient]);

  const pushSupportNotification = useCallback(
    (type: ToastState["type"], message: string) => {
      const supportConversationPathId = encodeURIComponent(conversationId);
      addNotification({
        title: locale === "ru" ? "Поддержка" : "Support",
        message,
        category: "support",
        source: "support-workspace",
        tone: type === "success" ? "success" : "error",
        href: `/${locale}/support/${supportConversationPathId}`,
      });
    },
    [addNotification, conversationId, locale]
  );

  const pushSupportError = useCallback(
    (error: unknown) => {
      const message = getAdminErrorMessage(error, text.supportLoadError);
      setToast({ type: "error", message });
      pushSupportNotification("error", message);
    },
    [pushSupportNotification, text.supportLoadError]
  );

  const assertCanManageSupportWorkspace = useCallback(() => {
    if (canManageSupportWorkspace) {
      return true;
    }

    setToast({ type: "error", message: supportActionsForbidden });
    pushSupportNotification("error", supportActionsForbidden);
    return false;
  }, [canManageSupportWorkspace, pushSupportNotification, supportActionsForbidden]);

  const setSupportSearchQuery = useCallback((value: string) => {
    setQueuePage(1);
    setRawSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH));
  }, []);

  const setSupportReply = useCallback((value: string) => {
    setReply(value.slice(0, SUPPORT_REPLY_MAX_LENGTH));
  }, []);

  const setSupportQueueFilter = useCallback((filter: SupportQueueFilter) => {
    setQueuePage(1);
    setQueueFilter(filter);
  }, []);

  const setSupportQueuePage = useCallback((value: number | ((currentPage: number) => number)) => {
    setQueuePage((currentPage) => {
      const nextPage = typeof value === "function" ? value(currentPage) : value;
      return Math.max(1, nextPage);
    });
  }, []);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2400);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const attachmentPreviewUrl = useMemo(() => {
    if (!selectedAttachment || !selectedAttachment.type.startsWith("image/")) {
      return null;
    }

    return URL.createObjectURL(selectedAttachment);
  }, [selectedAttachment]);

  useEffect(() => {
    return () => {
      if (attachmentPreviewUrl) {
        URL.revokeObjectURL(attachmentPreviewUrl);
      }
    };
  }, [attachmentPreviewUrl]);

  useEffect(
    () => () => {
      if (markReadDebounceRef.current) {
        clearTimeout(markReadDebounceRef.current);
        markReadDebounceRef.current = null;
      }
      loadOlderAbortControllerRef.current?.abort();
      for (const url of optimisticAttachmentObjectUrlsRef.current.values()) {
        URL.revokeObjectURL(url);
      }
      optimisticAttachmentObjectUrlsRef.current.clear();
    },
    []
  );

  const conversationQuery = useQuery<AdminSupportConversation>({
    queryKey: adminQueryKeys.supportConversation(conversationId),
    queryFn: ({ signal }) =>
      fetchSupportConversation(conversationId, {
        take: supportConversationMessagesTake,
        signal,
      }),
    enabled: Boolean(session && canManageSupportWorkspace),
    refetchInterval: false,
    refetchIntervalInBackground: false,
  });

  const resolvedQueueFilter = resolveQueueFilter(queueFilter);
  const effectiveQueueStatus =
    queueStatusFilter === "all" ? resolvedQueueFilter.status : queueStatusFilter;
  const inboxQuery = useQuery<AdminSupportInboxPage>({
    queryKey: adminQueryKeys.supportInbox(
      effectiveQueueStatus ?? "all",
      resolvedQueueFilter.assignment,
      {
        search: debouncedSearchQuery,
        page: queuePage,
        pageSize: SUPPORT_INBOX_PAGE_SIZE,
      }
    ),
    queryFn: ({ signal }) => {
      return fetchSupportInbox(effectiveQueueStatus, resolvedQueueFilter.assignment, {
        search: debouncedSearchQuery,
        page: queuePage,
        pageSize: SUPPORT_INBOX_PAGE_SIZE,
        signal,
      });
    },
    enabled: Boolean(session && canManageSupportWorkspace),
    refetchInterval: session && canManageSupportWorkspace ? supportPollingIntervalMs : false,
    refetchIntervalInBackground: false,
  });
  const inboxMetricsQuery = useQuery<AdminSupportInboxMetrics>({
    queryKey: adminQueryKeys.supportInboxMetrics,
    queryFn: ({ signal }) => fetchSupportInboxMetrics(signal),
    enabled: Boolean(session && canManageSupportWorkspace),
    refetchInterval: session && canManageSupportWorkspace ? supportPollingIntervalMs : false,
    refetchIntervalInBackground: false,
  });

  const conversation = conversationQuery.data;
  const sessionUserId = session?.user.userId ?? null;
  const canViewSubjectUserContext = sessionUserRoles.includes("Admin");
  const isAssignedToCurrentAdmin = Boolean(
    sessionUserId && conversation?.assignedAdminId === sessionUserId
  );
  const subjectUserId = conversation?.initiatorUserId ?? null;

  useSupportRealtime(canManageSupportWorkspace ? session?.accessToken : undefined, (event) => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot });
    if (event.conversationId === conversationId) {
      const now = Date.now();
      if (now - lastConversationRealtimeFetchRef.current < 700) {
        return;
      }

      lastConversationRealtimeFetchRef.current = now;
      void queryClient
        .fetchQuery({
          queryKey: adminQueryKeys.supportConversation(conversationId),
          queryFn: ({ signal }) =>
            fetchSupportConversation(conversationId, {
              take: supportConversationMessagesTake,
              signal,
            }),
        })
        .then((latestConversation) => {
          queryClient.setQueryData<AdminSupportConversation>(
            adminQueryKeys.supportConversation(conversationId),
            (currentConversation) => {
              if (!currentConversation) {
                return latestConversation;
              }

              return mergeSupportConversationMessages(currentConversation, latestConversation);
            }
          );
        })
        .catch((error) => {
          clientLogger.warn("support.realtime_fetch_conversation_failed", {
            conversationId,
            error,
          });
          void queryClient.invalidateQueries({
            queryKey: adminQueryKeys.supportConversation(conversationId),
          });
        });
      return;
    }

    const toastKey = `${event.conversationId}:${event.updatedAtUtc}`;
    if (isUserSupportMessageEvent(event) && lastRealtimeToastRef.current !== toastKey) {
      lastRealtimeToastRef.current = toastKey;
      setToast({ type: "success", message: buildSupportRealtimeToastMessage(event, locale) });
    }
  });

  const attemptMarkRead = useCallback(() => {
    if (
      !canManageSupportWorkspace ||
      !conversationQuery.data ||
      conversationQuery.data.adminUnreadCount <= 0 ||
      markReadRequestRef.current
    ) {
      return;
    }

    // The conversation is only considered "read" when the operator is actively
    // looking at it: the tab is visible, the browser window is focused, and the
    // newest messages are actually scrolled into the visible area.
    if (document.visibilityState !== "visible") {
      return;
    }

    if (typeof document.hasFocus === "function" && !document.hasFocus()) {
      return;
    }

    if (!messagesViewportVisibleRef.current) {
      return;
    }

    markReadRequestRef.current = markSupportConversationRead(conversationId)
      .then(refreshConversationData)
      .catch((error) => {
        clientLogger.warn("support.mark_read_failed", {
          conversationId,
          error,
        });
      })
      .finally(() => {
        markReadRequestRef.current = null;
      });
  }, [canManageSupportWorkspace, conversationId, conversationQuery.data, refreshConversationData]);

  const scheduleMarkRead = useCallback(() => {
    if (markReadDebounceRef.current) {
      clearTimeout(markReadDebounceRef.current);
    }

    markReadDebounceRef.current = setTimeout(() => {
      attemptMarkRead();
    }, 1500);
  }, [attemptMarkRead]);

  // Signalled by the conversation view through an IntersectionObserver so the
  // controller knows whether the latest messages are inside the viewport.
  const setMessagesViewportVisible = useCallback(
    (visible: boolean) => {
      messagesViewportVisibleRef.current = visible;
      if (visible) {
        scheduleMarkRead();
      }
    },
    [scheduleMarkRead]
  );

  const loadOlderMessages = useCallback(async () => {
    if (!canManageSupportWorkspace) {
      return;
    }

    const currentConversation = queryClient.getQueryData<AdminSupportConversation>(
      adminQueryKeys.supportConversation(conversationId)
    );
    if (!currentConversation?.hasOlderMessages) {
      return;
    }

    const beforeMessageCreatedAtUtc = currentConversation.oldestLoadedMessageCreatedAtUtc;
    if (!beforeMessageCreatedAtUtc) {
      return;
    }
    const beforeMessageId = currentConversation.messages[0]?.messageId;

    loadOlderAbortControllerRef.current?.abort();
    const abortController = new AbortController();
    loadOlderAbortControllerRef.current = abortController;

    let olderConversation: AdminSupportConversation;
    try {
      olderConversation = await fetchSupportConversation(conversationId, {
        take: supportConversationMessagesTake,
        beforeMessageCreatedAtUtc,
        beforeMessageId,
        signal: abortController.signal,
      });
    } catch (error) {
      if (abortController.signal.aborted) {
        return;
      }

      throw error;
    } finally {
      if (loadOlderAbortControllerRef.current === abortController) {
        loadOlderAbortControllerRef.current = null;
      }
    }

    queryClient.setQueryData<AdminSupportConversation>(
      adminQueryKeys.supportConversation(conversationId),
      (latestConversation) => {
        if (!latestConversation) {
          return olderConversation;
        }

        return mergeSupportConversationMessages(latestConversation, olderConversation);
      }
    );
  }, [canManageSupportWorkspace, conversationId, queryClient]);

  useEffect(() => {
    if (!conversationQuery.data || conversationQuery.data.adminUnreadCount <= 0) {
      return;
    }

    scheduleMarkRead();

    return () => {
      if (markReadDebounceRef.current) {
        clearTimeout(markReadDebounceRef.current);
      }
    };
  }, [conversationQuery.data, scheduleMarkRead]);

  useEffect(() => {
    const handleActiveAgain = () => {
      if (document.visibilityState === "visible") {
        scheduleMarkRead();
      }
    };

    document.addEventListener("visibilitychange", handleActiveAgain);
    window.addEventListener("focus", handleActiveAgain);
    return () => {
      document.removeEventListener("visibilitychange", handleActiveAgain);
      window.removeEventListener("focus", handleActiveAgain);
    };
  }, [scheduleMarkRead]);

  const sendMutation = useMutation({
    mutationFn: async () => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }

      return selectedAttachment
        ? sendSupportAttachment(conversationId, selectedAttachment, reply.trim(), replyToMessageId)
        : sendSupportMessage(conversationId, reply.trim(), replyToMessageId);
    },
    onMutate: async (): Promise<SendOptimisticContext> => {
      if (!canManageSupportWorkspace) {
        return {};
      }

      const trimmedReply = reply.trim();
      const hasAttachment = Boolean(selectedAttachment);
      const canApplyOptimisticMessage = hasAttachment || trimmedReply.length > 0;
      if (!canApplyOptimisticMessage) {
        return {};
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      await queryClient.cancelQueries({ queryKey });
      const previousConversation = queryClient.getQueryData<AdminSupportConversation>(queryKey);
      if (!previousConversation) {
        return {};
      }

      optimisticMessageCounterRef.current += 1;
      const optimisticMessageId = `optimistic-${conversationId}-${optimisticMessageCounterRef.current}`;
      const nowUtc = new Date().toISOString();
      const optimisticAttachmentObjectUrl = selectedAttachment
        ? URL.createObjectURL(selectedAttachment)
        : undefined;
      const optimisticLastMessagePreview =
        trimmedReply ||
        (selectedAttachment?.name?.trim()
          ? `${locale === "ru" ? "Вложение" : "Attachment"}: ${selectedAttachment.name.trim()}`
          : locale === "ru"
            ? "Вложение"
            : "Attachment");
      const optimisticMessage = {
        messageId: optimisticMessageId,
        conversationId,
        senderUserId: session?.user.userId ?? "admin",
        senderDisplayName:
          session?.user.displayName?.trim() ||
          (session?.user.email ? maskEmail(session.user.email) : null) ||
          (locale === "ru" ? "Оператор" : "Operator"),
        isFromAdmin: true,
        senderType: "Admin",
        body: trimmedReply,
        replyToMessageId: replyToMessageId?.trim() || null,
        replyToPreview: replyToPreview?.trim() || null,
        attachmentUrl: optimisticAttachmentObjectUrl ?? null,
        attachmentFileName: selectedAttachment?.name ?? null,
        attachmentContentType:
          selectedAttachment?.type?.trim() ||
          (selectedAttachment ? "application/octet-stream" : null),
        attachmentFileSizeBytes: selectedAttachment?.size ?? null,
        attachmentUploadStatus: selectedAttachment ? "uploading" : null,
        attachmentUploadErrorCode: null,
        attachments: selectedAttachment
          ? [
              {
                fileUrl: optimisticAttachmentObjectUrl!,
                type: selectedAttachment.type,
                mimeType: selectedAttachment.type || "application/octet-stream",
                fileName: selectedAttachment.name,
                sizeBytes: selectedAttachment.size,
                isDeleted: false,
                expiresAtUtc: null,
                deletedAtUtc: null,
                durationSeconds: null,
                width: null,
                height: null,
              },
            ]
          : null,
        isRead: false,
        readAtUtc: null,
        deliveredAtUtc: null,
        isInternalNote: false,
        createdAtUtc: nowUtc,
      };

      if (optimisticAttachmentObjectUrl) {
        optimisticAttachmentObjectUrlsRef.current.set(
          optimisticMessageId,
          optimisticAttachmentObjectUrl
        );
      }

      queryClient.setQueryData<AdminSupportConversation>(queryKey, {
        ...previousConversation,
        messages: [...previousConversation.messages, optimisticMessage],
        lastMessageAtUtc: nowUtc,
        lastMessagePreview: optimisticLastMessagePreview,
        lastMessageSenderType: "Admin",
        updatedAtUtc: nowUtc,
      });

      return { previousConversation, optimisticMessageId, optimisticAttachmentObjectUrl };
    },
    onSuccess: async (_data, _variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      queryClient.setQueryData<AdminSupportConversation>(queryKey, (currentConversation) => {
        if (!currentConversation) {
          return currentConversation;
        }

        return {
          ...currentConversation,
          messages: currentConversation.messages.filter(
            (message) => !message.messageId.startsWith("optimistic-")
          ),
        };
      });

      setReply("");
      setReplyToMessageId(null);
      setReplyToPreview(null);
      resetSelectedAttachment();
      setToast({ type: "success", message: text.supportReplySent });
      pushSupportNotification("success", text.supportReplySent);
      await refreshConversationData();
    },
    onError: (error, _variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      if (context?.previousConversation) {
        queryClient.setQueryData(
          adminQueryKeys.supportConversation(conversationId),
          context.previousConversation
        );
      }

      pushSupportError(error);
    },
    onSettled: () => {
      sendReplyInFlightRef.current = false;
      setIsSendReplyInFlight(false);
    },
  });

  const isSendReplySubmitting = isSendReplyInFlight || sendMutation.isPending;

  const requestSendReply = useCallback(() => {
    if (
      !canManageSupportWorkspace ||
      sendReplyInFlightRef.current ||
      sendMutation.isPending ||
      (!reply.trim() && !selectedAttachment)
    ) {
      return false;
    }

    sendReplyInFlightRef.current = true;
    setIsSendReplyInFlight(true);
    sendMutation.mutate();
    return true;
  }, [canManageSupportWorkspace, reply, selectedAttachment, sendMutation]);

  const statusMutation = useMutation({
    mutationFn: async (status: SupportConversationStatus) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }

      return updateSupportConversationStatus(conversationId, status);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportStatusSaved });
      pushSupportNotification("success", text.supportStatusSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error);
    },
  });

  const assignmentMutation = useMutation({
    mutationFn: async (assignedAdminId?: string | null) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }

      return assignSupportConversation(conversationId, assignedAdminId);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportAssignmentSaved });
      pushSupportNotification("success", text.supportAssignmentSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error);
    },
  });

  const metadataMutation = useMutation({
    mutationFn: async (payload: { priority: SupportConversationPriority; tags: string[] }) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }

      return updateSupportConversationMetadata(conversationId, payload);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportStatusSaved });
      pushSupportNotification("success", text.supportStatusSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error);
    },
  });

  const userQuery = useQuery<AdminUserDetail>({
    queryKey: subjectUserId
      ? adminQueryKeys.userDetail(subjectUserId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(subjectUserId!, signal),
    enabled: Boolean(session && subjectUserId && canViewSubjectUserContext),
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const isSubjectUserDeleted = Boolean(
    subjectUserId && userQuery.isError && isNotFoundError(userQuery.error)
  );

  const analyticsQuery = useQuery<AdminUserAnalytics>({
    queryKey: subjectUserId
      ? adminQueryKeys.userAnalytics(subjectUserId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(subjectUserId!, signal),
    enabled: Boolean(
      session && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const purchasesQuery = useQuery<AdminEconomyPurchase[]>({
    queryKey: ["admin", "support", "conversation", subjectUserId ?? "none", "purchases"],
    queryFn: async ({ signal }) => {
      const response = await fetchAdminEconomyPurchases(
        {
          skip: 0,
          take: 8,
          userId: subjectUserId!,
        },
        signal
      );

      return response.items;
    },
    enabled: Boolean(
      session && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const subscriptionQuery = useQuery<AdminEconomyUserSubscriptionSummary>({
    queryKey: subjectUserId
      ? adminQueryKeys.economyUserSubscriptionSummary(subjectUserId)
      : adminQueryKeys.economyUserSubscriptionSummaryDisabled,
    queryFn: ({ signal }) => fetchAdminEconomyUserSubscriptionSummary(subjectUserId!, signal),
    enabled: Boolean(
      session && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const filteredInboxItems = useMemo<AdminSupportConversationSummary[]>(
    () => sortSupportQueueItems(inboxQuery.data?.items ?? []),
    [inboxQuery.data]
  );
  const canGoToPreviousQueuePage = queuePage > 1;
  const canGoToNextQueuePage = Boolean(inboxQuery.data?.hasMore);

  const composerValue = reply;
  const composerPlaceholder = text.supportReplyPlaceholder;
  const deletedUserNameFallback = locale === "ru" ? "Удаленный пользователь" : "Deleted user";
  const deletedUserEmailFallback = locale === "ru" ? "Пользователь удален" : "User deleted";
  const userEmailDisplay = conversation?.userEmail?.trim()
    ? maskEmail(conversation.userEmail)
    : isSubjectUserDeleted
      ? deletedUserEmailFallback
      : "";
  const userDisplayName = conversation?.userDisplayName?.trim()
    ? formatSafeSupportDisplay(conversation.userDisplayName, text.supportConversationTitle, 72)
    : userEmailDisplay ||
      (isSubjectUserDeleted ? deletedUserNameFallback : "") ||
      text.supportConversationTitle;
  const hasComposerAttachment = selectedAttachment !== null;
  const replyToMessage = useMemo(
    () =>
      replyToMessageId
        ? (conversation?.messages.find((message) => message.messageId === replyToMessageId) ?? null)
        : null,
    [conversation?.messages, replyToMessageId]
  );

  const selectReplyToMessage = useCallback(
    (messageId: string | null, preview?: string | null) => {
      setReplyToMessageId(messageId);
      setReplyToPreview(messageId ? preview?.trim() || null : null);
    },
    [setReplyToMessageId, setReplyToPreview]
  );

  const operatorPriority: SupportConversationPriority = conversation?.priority ?? "Normal";

  const operatorTags = conversation?.tags ?? [];

  const setOperatorPriority = useCallback(
    (priority: SupportConversationPriority) => {
      if (!conversation || !canManageSupportWorkspace || metadataMutation.isPending) {
        return;
      }

      const currentTags = conversation.tags ?? [];
      metadataMutation.mutate({ priority, tags: currentTags });
    },
    [canManageSupportWorkspace, conversation, metadataMutation]
  );

  const addOperatorTag = useCallback(
    (rawTag: string) => {
      if (!conversation || !canManageSupportWorkspace || metadataMutation.isPending) {
        return false;
      }

      const tag = normalizeSupportTag(rawTag);
      if (!tag) {
        return false;
      }

      const currentTags = conversation.tags ?? [];
      const nextTags = Array.from(new Set([...currentTags, tag])).slice(0, 12);
      if (nextTags.length === currentTags.length) {
        return false;
      }

      metadataMutation.mutate({
        priority: conversation.priority,
        tags: nextTags,
      });

      return true;
    },
    [canManageSupportWorkspace, conversation, metadataMutation]
  );

  const removeOperatorTag = useCallback(
    (tagToRemove: string) => {
      if (!conversation || !canManageSupportWorkspace || metadataMutation.isPending) {
        return;
      }

      const currentTags = conversation.tags ?? [];
      const nextTags = currentTags.filter((tag) => tag !== tagToRemove);
      if (nextTags.length === currentTags.length) {
        return;
      }

      metadataMutation.mutate({
        priority: conversation.priority,
        tags: nextTags,
      });
    },
    [canManageSupportWorkspace, conversation, metadataMutation]
  );

  const sidePanelTabs: ReadonlyArray<{ value: SidePanelTab; label: string }> = [
    { value: "user", label: text.supportViewUserTab },
    { value: "activity", label: text.supportViewActivityTab },
    { value: "dialog", label: text.supportViewDialogTab },
    { value: "attachments", label: text.supportViewAttachmentsTab },
  ];

  const sidePanelTitle =
    activeSidePanelTab === "user"
      ? text.supportUserInformationTitle
      : activeSidePanelTab === "activity"
        ? text.supportActivityTitle
        : activeSidePanelTab === "dialog"
          ? text.supportDialogTitle
          : text.supportAttachmentsTitle;

  const sidePanelDescription =
    activeSidePanelTab === "activity"
      ? text.supportActivityDescription
      : activeSidePanelTab === "dialog"
        ? text.supportDialogDescription
        : activeSidePanelTab === "attachments"
          ? text.supportAttachmentsDescription
          : null;

  const accountCreatedAt = userQuery.data?.createdAtUtc ?? conversation?.createdAtUtc ?? null;
  const conversationWaitingSince =
    conversation?.waitingSinceUtc ??
    conversation?.lastMessageAtUtc ??
    conversation?.createdAtUtc ??
    null;
  const conversationSla = getConversationSla(
    conversationWaitingSince,
    locale,
    conversation?.adminUnreadCount ?? 0
  );
  const recentUserPurchases = purchasesQuery.data ?? [];
  const totalPurchases = canViewSubjectUserContext
    ? (analyticsQuery.data?.summary.totalPurchases ?? recentUserPurchases.length)
    : 0;
  const lastUserPurchaseAtUtc =
    recentUserPurchases[0]?.confirmedAtUtc ?? recentUserPurchases[0]?.createdAtUtc ?? null;
  const lastActivityAtUtc =
    analyticsQuery.data?.summary.lastActivityAtUtc ??
    conversation?.lastMessageAtUtc ??
    conversation?.updatedAtUtc ??
    conversation?.createdAtUtc ??
    null;
  const failedGenerations =
    analyticsQuery.data?.recentGenerations.filter(
      (generation) => generation.status.toLowerCase() === "failed"
    ) ?? [];
  const recentFailures = analyticsQuery.data?.failureBreakdown.slice(0, 4) ?? [];

  const chatFacts = [
    ...(canViewSubjectUserContext
      ? [userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel]
      : []),
    formatAccountAgeFact(accountCreatedAt, locale),
    formatCountFact(conversation?.messages.length ?? 0, locale, "messages"),
    ...(canViewSubjectUserContext
      ? [
          formatCountFact(
            analyticsQuery.data?.summary.totalPurchases ?? recentUserPurchases.length,
            locale,
            "purchases"
          ),
        ]
      : []),
  ];

  const activityTimeline: SupportTimelineItem[] = buildActivityTimeline(analyticsQuery.data);
  const availableStatusActions = conversation
    ? getAvailableStatusActions(conversation.status, text)
    : [];
  const primaryStatusAction =
    availableStatusActions.find((action) => action.variant === "primary") ?? null;
  const secondaryStatusActions = availableStatusActions.filter(
    (action) => action.variant === "secondary"
  );
  const destructiveStatusAction =
    availableStatusActions.find((action) => action.variant === "danger") ?? null;

  const conversationTimeline: SupportTimelineItem[] = buildConversationTimeline({
    conversation,
    userDisplayName,
    labels: {
      conversationCreated: text.supportTimelineConversationCreated,
      adminReply: text.supportTimelineAdminReply,
      userMessage: text.supportTimelineUserMessage,
    },
  });

  return {
    activeSidePanelTab,
    accountCreatedAt,
    activityTimeline,
    analyticsQuery,
    assignmentMutation,
    attachmentInputRef,
    attachmentPreviewUrl,
    chatFacts,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    filteredInboxItems,
    canViewSubjectUserContext,
    canManageSupportWorkspace,
    canGoToNextQueuePage,
    canGoToPreviousQueuePage,
    hasComposerAttachment,
    inboxMetrics: inboxMetricsQuery.data ?? null,
    inboxMetricsQuery,
    inboxQuery,
    isAssignedToCurrentAdmin,
    isSidePanelOpen,
    primaryStatusAction,
    purchasesQuery,
    recentUserPurchases,
    lastUserPurchaseAtUtc,
    lastActivityAtUtc,
    recentFailures,
    reply,
    replyToMessage,
    replyToPreview,
    requestSendReply,
    resetSelectedAttachment,
    searchQuery,
    selectedAttachment,
    secondaryStatusActions,
    sendMutation,
    isSendReplySubmitting,
    sessionUserId,
    sessionUserRoles,
    setActiveSidePanelTab,
    setIsSidePanelOpen,
    setReply: setSupportReply,
    setReplyToMessageId,
    setReplyToPreview,
    setSearchQuery: setSupportSearchQuery,
    setQueueFilter: setSupportQueueFilter,
    setQueuePage: setSupportQueuePage,
    setSelectedAttachment,
    setMessagesViewportVisible,
    loadOlderMessages,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    operatorPriority,
    operatorTags,
    setOperatorPriority,
    addOperatorTag,
    removeOperatorTag,
    queueFilter,
    queuePage,
    isSubjectUserDeleted,
    subscriptionQuery,
    statusMutation,
    text,
    toast,
    totalPurchases,
    selectReplyToMessage,
    userEmailDisplay,
    userDisplayName,
    userQuery,
  };
}
