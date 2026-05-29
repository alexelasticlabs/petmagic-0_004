"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { useAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  buildActivityTimeline,
  buildConversationTimeline,
  formatAccountAgeFact,
  formatCountFact,
  getConversationSla,
  sortSupportQueueItems,
  type SupportTimelineItem,
} from "@/components/support/support-conversation-helpers";
import { getAvailableStatusActions } from "@/components/support/support-status-helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignSupportConversation,
  fetchAdminEconomyPurchases,
  fetchAdminEconomyUserSubscriptionSummary,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  fetchSupportConversation,
  fetchSupportInbox,
  markSupportConversationRead,
  sendSupportAttachment,
  sendSupportMessage,
  setActive,
  setPremium,
  updateSupportConversationMetadata,
  updateSupportConversationStatus,
  useAuthSession,
  type AdminEconomyPurchase,
  type AdminEconomyUserSubscriptionSummary,
  type AdminSupportConversation,
  type AdminSupportConversationSummary,
  type AdminUserAnalytics,
  type AdminUserDetail,
  type SupportConversationPriority,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";

type UseSupportConversationControllerParams = {
  locale: Locale;
  conversationId: string;
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

function buildSupportRealtimeToastMessage(
  event: { lastMessagePreview?: string | null },
  locale: Locale
): string {
  const fallback = locale === "ru" ? "Новое сообщение в поддержке" : "New support message";
  const preview = event.lastMessagePreview?.trim();
  if (!preview) {
    return fallback;
  }

  const safePreview = preview.length > 96 ? `${preview.slice(0, 93)}...` : preview;
  return locale === "ru"
    ? `Новое сообщение: ${safePreview}`
    : `New support message: ${safePreview}`;
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

const supportPollingIntervalMs = 5_000;

export function useSupportConversationController({
  locale,
  conversationId,
}: UseSupportConversationControllerParams) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const { addNotification } = useAdminNotifications();
  const [queueFilter, setQueueFilter] = useState<SupportQueueFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [reply, setReply] = useState("");
  const [replyToMessageId, setReplyToMessageId] = useState<string | null>(null);
  const [replyToPreview, setReplyToPreview] = useState<string | null>(null);
  const [activeSidePanelTab, setActiveSidePanelTab] = useState<SidePanelTab>("user");
  const [isSidePanelOpen, setIsSidePanelOpen] = useState(
    () => typeof window !== "undefined" && window.matchMedia("(min-width: 1321px)").matches
  );
  const [toast, setToast] = useState<ToastState | null>(null);
  const [selectedAttachment, setSelectedAttachment] = useState<File | null>(null);
  const attachmentInputRef = useRef<HTMLInputElement | null>(null);
  const markReadRequestRef = useRef<Promise<void> | null>(null);
  const markReadDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastRealtimeToastRef = useRef<string | null>(null);
  const messagesViewportVisibleRef = useRef(false);
  const lastConversationRealtimeFetchRef = useRef(0);
  const optimisticAttachmentObjectUrlsRef = useRef(new Map<string, string>());

  const resetSelectedAttachment = useCallback(() => {
    setSelectedAttachment(null);
    if (attachmentInputRef.current) {
      attachmentInputRef.current.value = "";
    }
  }, []);

  const refreshConversationData = useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({
        queryKey: adminQueryKeys.supportConversation(conversationId),
      }),
      queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot }),
    ]);
  }, [conversationId, queryClient]);

  const pushSupportNotification = useCallback(
    (type: ToastState["type"], message: string) => {
      addNotification({
        title: locale === "ru" ? "Поддержка" : "Support",
        message,
        category: "support",
        source: "support-workspace",
        tone: type === "success" ? "success" : "error",
        href: `/${locale}/support/${conversationId}`,
      });
    },
    [addNotification, conversationId, locale]
  );

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

  useEffect(
    () => () => {
      if (attachmentPreviewUrl) {
        URL.revokeObjectURL(attachmentPreviewUrl);
      }

      for (const url of optimisticAttachmentObjectUrlsRef.current.values()) {
        URL.revokeObjectURL(url);
      }
      optimisticAttachmentObjectUrlsRef.current.clear();
    },
    [attachmentPreviewUrl]
  );

  const conversationQuery = useQuery<AdminSupportConversation>({
    queryKey: adminQueryKeys.supportConversation(conversationId),
    queryFn: () => fetchSupportConversation(conversationId),
    enabled: Boolean(session),
    refetchInterval: session ? supportPollingIntervalMs : false,
    refetchIntervalInBackground: false,
  });

  const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
    queryKey: adminQueryKeys.supportInbox(
      resolveQueueFilter(queueFilter).status ?? "all",
      resolveQueueFilter(queueFilter).assignment
    ),
    queryFn: () => {
      const { status, assignment } = resolveQueueFilter(queueFilter);
      return fetchSupportInbox(status, assignment);
    },
    enabled: Boolean(session),
    refetchInterval: session ? supportPollingIntervalMs : false,
    refetchIntervalInBackground: false,
  });

  const conversation = conversationQuery.data;
  const sessionUserId = session?.user.userId ?? null;
  const isAssignedToCurrentAdmin = Boolean(
    sessionUserId && conversation?.assignedAdminId === sessionUserId
  );
  const subjectUserId = conversation?.initiatorUserId ?? null;

  useSupportRealtime(session?.accessToken, (event) => {
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
          queryFn: () => fetchSupportConversation(conversationId),
        })
        .catch(() => {
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
      .catch(() => undefined)
      .finally(() => {
        markReadRequestRef.current = null;
      });
  }, [conversationId, conversationQuery.data, refreshConversationData]);

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
    mutationFn: async () =>
      selectedAttachment
        ? sendSupportAttachment(conversationId, selectedAttachment, reply.trim(), replyToMessageId)
        : sendSupportMessage(conversationId, reply.trim(), replyToMessageId),
    onMutate: async (): Promise<SendOptimisticContext> => {
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

      const optimisticMessageId = `optimistic-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
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
          session?.user.displayName?.trim() || session?.user.email || (locale === "ru" ? "Оператор" : "Operator"),
        isFromAdmin: true,
        senderType: "Admin",
        body: trimmedReply,
        replyToMessageId: replyToMessageId?.trim() || null,
        replyToPreview: replyToPreview?.trim() || null,
        attachmentUrl: optimisticAttachmentObjectUrl ?? null,
        attachmentFileName: selectedAttachment?.name ?? null,
        attachmentContentType:
          selectedAttachment?.type?.trim() || (selectedAttachment ? "application/octet-stream" : null),
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
    onError: (_error, _variables, context) => {
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

      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const statusMutation = useMutation({
    mutationFn: async (status: SupportConversationStatus) =>
      updateSupportConversationStatus(conversationId, status),
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportStatusSaved });
      pushSupportNotification("success", text.supportStatusSaved);
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const assignmentMutation = useMutation({
    mutationFn: async (assignedAdminId?: string | null) =>
      assignSupportConversation(conversationId, assignedAdminId),
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportAssignmentSaved });
      pushSupportNotification("success", text.supportAssignmentSaved);
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const metadataMutation = useMutation({
    mutationFn: async (payload: { priority: SupportConversationPriority; tags: string[] }) =>
      updateSupportConversationMetadata(conversationId, payload),
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportStatusSaved });
      pushSupportNotification("success", text.supportStatusSaved);
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const setUserActiveMutation = useMutation({
    mutationFn: async (isActive: boolean) => {
      if (!subjectUserId) {
        throw new Error("support.subject_user_missing");
      }

      await setActive(subjectUserId, isActive);
      return isActive;
    },
    onSuccess: async (isActive) => {
      const message = isActive
        ? locale === "ru"
          ? "Пользователь активирован"
          : "User activated"
        : locale === "ru"
          ? "Пользователь заблокирован"
          : "User blocked";

      setToast({
        type: "success",
        message,
      });
      pushSupportNotification("success", message);

      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(subjectUserId!) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.supportConversation(conversationId),
        }),
      ]);
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const setUserPremiumMutation = useMutation({
    mutationFn: async (isPremium: boolean) => {
      if (!subjectUserId) {
        throw new Error("support.subject_user_missing");
      }

      await setPremium(subjectUserId, isPremium);
      return isPremium;
    },
    onSuccess: async (isPremium) => {
      const message = isPremium
        ? locale === "ru"
          ? "Премиум включен"
          : "Premium granted"
        : locale === "ru"
          ? "Премиум отключен"
          : "Premium revoked";

      setToast({
        type: "success",
        message,
      });
      pushSupportNotification("success", message);

      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(subjectUserId!) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userAnalytics(subjectUserId!) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyUserSubscriptionSummary(subjectUserId!),
        }),
      ]);
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
      pushSupportNotification("error", text.supportLoadError);
    },
  });

  const userQuery = useQuery<AdminUserDetail>({
    queryKey: subjectUserId
      ? adminQueryKeys.userDetail(subjectUserId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: () => fetchAdminUser(subjectUserId!),
    enabled: Boolean(session && subjectUserId),
  });

  const analyticsQuery = useQuery<AdminUserAnalytics>({
    queryKey: subjectUserId
      ? adminQueryKeys.userAnalytics(subjectUserId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: () => fetchAdminUserAnalytics(subjectUserId!),
    enabled: Boolean(session && subjectUserId),
  });

  const purchasesQuery = useQuery<AdminEconomyPurchase[]>({
    queryKey: ["admin", "support", "conversation", subjectUserId ?? "none", "purchases"],
    queryFn: async () => {
      const response = await fetchAdminEconomyPurchases({
        skip: 0,
        take: 8,
        userId: subjectUserId!,
      });

      return response.items;
    },
    enabled: Boolean(session && subjectUserId),
  });

  const subscriptionQuery = useQuery<AdminEconomyUserSubscriptionSummary>({
    queryKey: subjectUserId
      ? adminQueryKeys.economyUserSubscriptionSummary(subjectUserId)
      : adminQueryKeys.economyUserSubscriptionSummaryDisabled,
    queryFn: () => fetchAdminEconomyUserSubscriptionSummary(subjectUserId!),
    enabled: Boolean(session && subjectUserId),
  });

  const inboxItems = useMemo(() => sortSupportQueueItems(inboxQuery.data ?? []), [inboxQuery.data]);

  const filteredInboxItems = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    if (!normalizedQuery) {
      return inboxItems;
    }

    return inboxItems.filter((item) => {
      const haystacks = [
        item.userDisplayName,
        item.userEmail,
        item.lastMessagePreview,
        item.assignedAdminDisplayName,
        item.tags?.join(" "),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return haystacks.includes(normalizedQuery);
    });
  }, [inboxItems, searchQuery]);

  const composerValue = reply;
  const composerPlaceholder = text.supportReplyPlaceholder;
  const userDisplayName =
    conversation?.userDisplayName?.trim() ||
    conversation?.userEmail ||
    text.supportConversationTitle;
  const hasComposerAttachment = selectedAttachment !== null;
  const replyToMessage = useMemo(
    () =>
      replyToMessageId
        ? (conversation?.messages.find((message) => message.messageId === replyToMessageId) ?? null)
        : null,
    [conversation?.messages, replyToMessageId]
  );

  const selectReplyToMessage = useCallback((messageId: string | null, preview?: string | null) => {
    setReplyToMessageId(messageId);
    setReplyToPreview(messageId ? preview?.trim() || null : null);
  }, []);

  const operatorPriority: SupportConversationPriority = conversation?.priority ?? "Normal";

  const operatorTags = conversation?.tags ?? [];

  const setOperatorPriority = useCallback(
    (priority: SupportConversationPriority) => {
      if (!conversation || metadataMutation.isPending) {
        return;
      }

      const currentTags = conversation.tags ?? [];
      metadataMutation.mutate({ priority, tags: currentTags });
    },
    [conversation, metadataMutation]
  );

  const addOperatorTag = useCallback(
    (rawTag: string) => {
      if (!conversation || metadataMutation.isPending) {
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
    [conversation, metadataMutation]
  );

  const removeOperatorTag = useCallback(
    (tagToRemove: string) => {
      if (!conversation || metadataMutation.isPending) {
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
    [conversation, metadataMutation]
  );

  const sidePanelTabs = useMemo<ReadonlyArray<{ value: SidePanelTab; label: string }>>(
    () => [
      { value: "user", label: text.supportViewUserTab },
      { value: "activity", label: text.supportViewActivityTab },
      { value: "dialog", label: text.supportViewDialogTab },
      { value: "attachments", label: text.supportViewAttachmentsTab },
    ],
    [
      text.supportViewActivityTab,
      text.supportViewAttachmentsTab,
      text.supportViewDialogTab,
      text.supportViewUserTab,
    ]
  );

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
  const totalPurchases = analyticsQuery.data?.summary.totalPurchases ?? recentUserPurchases.length;
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
    userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel,
    formatAccountAgeFact(accountCreatedAt, locale),
    formatCountFact(conversation?.messages.length ?? 0, locale, "messages"),
    formatCountFact(
      analyticsQuery.data?.summary.totalPurchases ?? recentUserPurchases.length,
      locale,
      "purchases"
    ),
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
    hasComposerAttachment,
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
    resetSelectedAttachment,
    searchQuery,
    selectedAttachment,
    secondaryStatusActions,
    sendMutation,
    sessionUserId,
    setUserActiveMutation,
    setUserPremiumMutation,
    setActiveSidePanelTab,
    setIsSidePanelOpen,
    setReply,
    setReplyToMessageId,
    setReplyToPreview,
    setSearchQuery,
    setQueueFilter,
    setSelectedAttachment,
    setMessagesViewportVisible,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    operatorPriority,
    operatorTags,
    setOperatorPriority,
    addOperatorTag,
    removeOperatorTag,
    queueFilter,
    subscriptionQuery,
    statusMutation,
    text,
    toast,
    totalPurchases,
    selectReplyToMessage,
    userDisplayName,
    userQuery,
  };
}
