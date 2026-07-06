"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { useAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getSupportConversationDerivedState } from "@/components/support/support-conversation-controller.derived";
import {
  SUPPORT_INBOX_PAGE_SIZE,
  SUPPORT_REPLY_MAX_LENGTH,
  SUPPORT_SEARCH_MAX_LENGTH,
  buildSupportRealtimeToastMessage,
  formatSupportControllerLogText,
  getSupportControllerErrorDetails,
  isUserSupportMessageEvent,
  mergeSupportConversationMessages,
  normalizeSupportTag,
  resolveQueueFilter,
  supportConversationMessagesTake,
  supportInboxStaleTimeMs,
  supportPollingIntervalMs,
  supportRealtimeHealthyPollingIntervalMs,
  type SidePanelTab,
  type SupportQueueFilter,
  type ToastState,
  type UseSupportConversationControllerParams,
  useDebouncedValue,
} from "@/components/support/support-conversation-controller.helpers";
import { useSupportConversationMutations } from "@/components/support/support-conversation-controller.mutations";
import { useSupportConversationSubjectQueries } from "@/components/support/support-conversation-controller.subject";
import { sortSupportQueueItems } from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchSupportConversation,
  fetchSupportInbox,
  fetchSupportInboxMetrics,
  markSupportConversationRead,
  useAuthSession,
  type AdminSupportConversation,
  type AdminSupportConversationSummary,
  type AdminSupportInboxPage,
  type AdminSupportInboxMetrics,
  type SupportConversationPriority,
  type SupportInboxSort,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";

export {
  SUPPORT_REPLY_MAX_LENGTH,
  SUPPORT_SEARCH_MAX_LENGTH,
  statusOptions,
} from "@/components/support/support-conversation-controller.helpers";

export function useSupportConversationController({
  locale,
  conversationId,
  queueStatusFilter = "all",
}: UseSupportConversationControllerParams) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const copy = useMemo(() => getSupportConversationCopy(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const { addNotification } = useAdminNotifications();
  const sessionUserRoles = session?.user.roles ?? [];
  const canManageSupportWorkspace =
    sessionUserRoles.includes("Admin") || sessionUserRoles.includes("Moderator");
  const supportActionsForbidden = copy.controller.actionsForbidden;
  const [queueFilter, setQueueFilter] = useState<SupportQueueFilter>("all");
  const [queuePriorityFilter, setQueuePriorityFilter] = useState<
    "all" | SupportConversationPriority
  >("all");
  const [queueSort, setQueueSort] = useState<SupportInboxSort>("default");
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
  const [selectedAttachment, setSelectedAttachmentState] = useState<File | null>(null);
  const [attachmentPreview, setAttachmentPreview] = useState<{
    file: File;
    url: string;
  } | null>(null);
  const attachmentInputRef = useRef<HTMLInputElement | null>(null);
  const attachmentPreviewUrlRef = useRef<string | null>(null);
  const markReadRequestRef = useRef<Promise<void> | null>(null);
  const markReadDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastRealtimeToastRef = useRef<string | null>(null);
  const messagesViewportVisibleRef = useRef(false);
  const lastConversationRealtimeFetchRef = useRef(0);
  const loadOlderAbortControllerRef = useRef<AbortController | null>(null);

  const revokeAttachmentPreviewUrl = useCallback(() => {
    if (!attachmentPreviewUrlRef.current) {
      return;
    }

    URL.revokeObjectURL(attachmentPreviewUrlRef.current);
    attachmentPreviewUrlRef.current = null;
  }, []);

  const clearAttachmentPreview = useCallback(() => {
    revokeAttachmentPreviewUrl();
    setAttachmentPreview(null);
  }, [revokeAttachmentPreviewUrl]);

  const setSupportSelectedAttachment = useCallback(
    (file: File | null) => {
      clearAttachmentPreview();
      setSelectedAttachmentState(file);

      if (!file?.type.startsWith("image/")) {
        return;
      }

      const previewUrl = URL.createObjectURL(file);
      try {
        attachmentPreviewUrlRef.current = previewUrl;
        setAttachmentPreview({ file, url: previewUrl });
      } catch (error) {
        if (attachmentPreviewUrlRef.current === previewUrl) {
          attachmentPreviewUrlRef.current = null;
        }
        URL.revokeObjectURL(previewUrl);
        throw error;
      }
    },
    [clearAttachmentPreview]
  );

  const resetSelectedAttachment = useCallback(() => {
    setSupportSelectedAttachment(null);
    if (attachmentInputRef.current) {
      attachmentInputRef.current.value = "";
    }
  }, [setSupportSelectedAttachment]);

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
        title: copy.controller.notificationTitle,
        message,
        category: "support",
        source: "support-workspace",
        tone: type === "success" ? "success" : "error",
        href: `/${locale}/support/${supportConversationPathId}`,
      });
    },
    [addNotification, conversationId, copy.controller.notificationTitle, locale]
  );

  const pushSupportError = useCallback(
    (error: unknown, action = "support_action") => {
      const message = getAdminErrorMessage(error, text.supportLoadError);
      clientLogger.warn("support.action_failed", {
        conversationId: formatSupportControllerLogText(conversationId),
        action: formatSupportControllerLogText(action, 40),
        ...getSupportControllerErrorDetails(error),
      });
      setToast({ type: "error", message });
      pushSupportNotification("error", message);
    },
    [conversationId, pushSupportNotification, text.supportLoadError]
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

  const setSupportQueuePriorityFilter = useCallback(
    (priority: "all" | SupportConversationPriority) => {
      setQueuePage(1);
      setQueuePriorityFilter(priority);
    },
    []
  );

  const setSupportQueueSort = useCallback((sort: SupportInboxSort) => {
    setQueuePage(1);
    setQueueSort(sort);
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

  const attachmentPreviewUrl =
    attachmentPreview?.file === selectedAttachment ? attachmentPreview.url : null;

  useEffect(() => {
    return () => {
      revokeAttachmentPreviewUrl();
      if (markReadDebounceRef.current) {
        clearTimeout(markReadDebounceRef.current);
        markReadDebounceRef.current = null;
      }
      loadOlderAbortControllerRef.current?.abort();
    };
  }, [revokeAttachmentPreviewUrl]);

  const supportRealtimeStatus = useSupportRealtime(
    canManageSupportWorkspace ? session?.accessToken : undefined,
    (event) => {
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
              conversationId: formatSupportControllerLogText(conversationId),
              ...getSupportControllerErrorDetails(error),
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
        setToast({ type: "success", message: buildSupportRealtimeToastMessage(locale) });
      }
    }
  );
  const supportPollingEnabled = Boolean(session && canManageSupportWorkspace);
  const supportRealtimeAwarePollingInterval =
    supportRealtimeStatus === "connected"
      ? supportRealtimeHealthyPollingIntervalMs
      : supportPollingIntervalMs;

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
  const effectiveQueuePriority = queuePriorityFilter === "all" ? undefined : queuePriorityFilter;
  const inboxQuery = useQuery<AdminSupportInboxPage>({
    queryKey: adminQueryKeys.supportInbox(
      effectiveQueueStatus ?? "all",
      resolvedQueueFilter.assignment,
      {
        search: debouncedSearchQuery,
        priority: effectiveQueuePriority,
        sort: queueSort,
        queue: resolvedQueueFilter.queue,
        page: queuePage,
        pageSize: SUPPORT_INBOX_PAGE_SIZE,
      }
    ),
    queryFn: ({ signal }) => {
      return fetchSupportInbox(effectiveQueueStatus, resolvedQueueFilter.assignment, {
        search: debouncedSearchQuery,
        priority: effectiveQueuePriority,
        sort: queueSort,
        queue: resolvedQueueFilter.queue,
        page: queuePage,
        pageSize: SUPPORT_INBOX_PAGE_SIZE,
        signal,
      });
    },
    enabled: Boolean(session && canManageSupportWorkspace),
    staleTime: supportInboxStaleTimeMs,
    refetchInterval: supportPollingEnabled ? supportRealtimeAwarePollingInterval : false,
    refetchIntervalInBackground: false,
  });
  const inboxMetricsQuery = useQuery<AdminSupportInboxMetrics>({
    queryKey: adminQueryKeys.supportInboxMetrics,
    queryFn: ({ signal }) => fetchSupportInboxMetrics(signal),
    enabled: Boolean(session && canManageSupportWorkspace),
    staleTime: supportInboxStaleTimeMs,
    refetchInterval: supportPollingEnabled ? supportRealtimeAwarePollingInterval : false,
    refetchIntervalInBackground: false,
  });

  const conversation = conversationQuery.data;
  const sessionUserId = session?.user.userId ?? null;
  const canViewSubjectUserContext = sessionUserRoles.includes("Admin");
  const isAssignedToCurrentAdmin = Boolean(
    sessionUserId && conversation?.assignedAdminId === sessionUserId
  );
  const subjectUserId = conversation?.initiatorUserId ?? null;
  const { analyticsQuery, isSubjectUserDeleted, purchasesQuery, subscriptionQuery, userQuery } =
    useSupportConversationSubjectQueries({
      hasSession: Boolean(session),
      subjectUserId,
      canViewSubjectUserContext,
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
          conversationId: formatSupportControllerLogText(conversationId),
          ...getSupportControllerErrorDetails(error),
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

    if (abortController.signal.aborted) {
      return;
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

  const {
    assignmentMutation,
    isSendReplySubmitting,
    metadataMutation,
    requestSendReply,
    sendMutation,
    statusMutation,
  } = useSupportConversationMutations({
    conversationId,
    canManageSupportWorkspace,
    supportActionsForbidden,
    assertCanManageSupportWorkspace,
    reply,
    selectedAttachment,
    replyToMessageId,
    replyToPreview,
    sessionUser: session?.user,
    queryClient,
    optimisticAttachmentPreview: copy.controller.optimisticAttachmentPreview,
    operatorLabel: copy.shared.operator,
    supportReplySent: text.supportReplySent,
    supportStatusSaved: text.supportStatusSaved,
    supportAssignmentSaved: text.supportAssignmentSaved,
    pushSupportNotification,
    pushSupportError,
    setToast,
    resetSelectedAttachment,
    refreshConversationData,
    setReply,
    setReplyToMessageId,
    setReplyToPreview,
  });

  const filteredInboxItems = useMemo<AdminSupportConversationSummary[]>(
    () => sortSupportQueueItems(inboxQuery.data?.items ?? []),
    [inboxQuery.data]
  );
  const canGoToPreviousQueuePage = queuePage > 1;
  const canGoToNextQueuePage = Boolean(inboxQuery.data?.hasMore);

  const composerValue = reply;
  const composerPlaceholder = text.supportReplyPlaceholder;
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

  const recentUserPurchases = purchasesQuery.data ?? [];
  const {
    accountCreatedAt,
    activityTimeline,
    conversationSla,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    lastActivityAtUtc,
    lastUserPurchaseAtUtc,
    operatorPriority,
    operatorTags,
    primaryStatusAction,
    recentFailures,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    secondaryStatusActions,
    totalPurchases,
    userDisplayName,
    userEmailDisplay,
  } = getSupportConversationDerivedState({
    locale,
    activeSidePanelTab,
    text,
    copy: {
      deletedUserName: copy.shared.deletedUserName,
      deletedUserEmail: copy.shared.deletedUserEmail,
    },
    conversation,
    canViewSubjectUserContext,
    isSubjectUserDeleted,
    user: userQuery.data,
    analytics: analyticsQuery.data,
    recentUserPurchases,
  });

  return {
    activeSidePanelTab,
    accountCreatedAt,
    activityTimeline,
    analyticsQuery,
    assignmentMutation,
    attachmentInputRef,
    attachmentPreviewUrl,
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
    setQueuePriorityFilter: setSupportQueuePriorityFilter,
    setQueueSort: setSupportQueueSort,
    setSelectedAttachment: setSupportSelectedAttachment,
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
    queuePriorityFilter,
    queueSort,
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
