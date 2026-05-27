"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  buildActivityTimeline,
  buildConversationTimeline,
  formatAccountAgeFact,
  formatCountFact,
  getConversationSla,
  mergeTemplateDraft,
  sortSupportQueueItems,
  type SupportTimelineItem,
} from "@/components/support/support-conversation-helpers";
import { getAvailableStatusActions } from "@/components/support/support-status-helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignSupportConversation,
  createSupportReplyTemplate,
  deleteSupportReplyTemplate,
  fetchAdminEconomyPurchases,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  fetchSupportConversation,
  fetchSupportInbox,
  fetchSupportReplyTemplates,
  markSupportConversationRead,
  sendSupportAttachment,
  sendSupportMessage,
  updateSupportConversationStatus,
  updateSupportReplyTemplate,
  useAuthSession,
  type AdminEconomyPurchase,
  type AdminSupportConversation,
  type AdminSupportConversationSummary,
  type AdminSupportReplyTemplate,
  type AdminUserAnalytics,
  type AdminUserDetail,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";

type UseSupportConversationControllerParams = {
  locale: Locale;
  conversationId: string;
};

export type ToastState = {
  type: "success" | "error";
  message: string;
};

export type SupportFilter = "all" | SupportConversationStatus;
export type AssignmentFilter = SupportInboxAssignmentScope;

export type SidePanelTab = "user" | "activity" | "dialog" | "attachments";

export type TemplateDraft = {
  templateId: string | null;
  title: string;
  body: string;
  isEnabled: boolean;
  sortOrder: number;
};

export const statusOptions: SupportConversationStatus[] = [
  "Open",
  "WaitingForSupport",
  "WaitingForUser",
  "Resolved",
  "Closed",
];

export const emptyTemplateDraft: TemplateDraft = {
  templateId: null,
  title: "",
  body: "",
  isEnabled: true,
  sortOrder: 0,
};

export function useSupportConversationController({
  locale,
  conversationId,
}: UseSupportConversationControllerParams) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState<SupportFilter>("all");
  const [assignmentFilter, setAssignmentFilter] = useState<AssignmentFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [reply, setReply] = useState("");
  const [templateDraft, setTemplateDraft] = useState<TemplateDraft>(emptyTemplateDraft);
  const [templateSearchQuery, setTemplateSearchQuery] = useState("");
  const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
  const [isTemplateEditorOpen, setIsTemplateEditorOpen] = useState(false);
  const [activeSidePanelTab, setActiveSidePanelTab] = useState<SidePanelTab>("user");
  const [isSidePanelOpen, setIsSidePanelOpen] = useState(
    () => typeof window !== "undefined" && window.matchMedia("(min-width: 1321px)").matches
  );
  const [toast, setToast] = useState<ToastState | null>(null);
  const [selectedAttachment, setSelectedAttachment] = useState<File | null>(null);
  const attachmentInputRef = useRef<HTMLInputElement | null>(null);
  const markReadRequestRef = useRef<Promise<void> | null>(null);

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

  const refreshTemplateCatalog = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportTemplates });
  }, [queryClient]);

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
    },
    [attachmentPreviewUrl]
  );

  const conversationQuery = useQuery<AdminSupportConversation>({
    queryKey: adminQueryKeys.supportConversation(conversationId),
    queryFn: () => fetchSupportConversation(conversationId),
    enabled: Boolean(session),
  });

  const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
    queryKey: adminQueryKeys.supportInbox(statusFilter, assignmentFilter),
    queryFn: () =>
      fetchSupportInbox(statusFilter === "all" ? undefined : statusFilter, assignmentFilter),
    enabled: Boolean(session),
  });

  const templatesQuery = useQuery<AdminSupportReplyTemplate[]>({
    queryKey: adminQueryKeys.supportTemplates,
    queryFn: () => fetchSupportReplyTemplates(),
    enabled: Boolean(session),
  });

  useSupportRealtime(session?.accessToken, (event) => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot });
    if (event.conversationId === conversationId) {
      void queryClient.invalidateQueries({
        queryKey: adminQueryKeys.supportConversation(conversationId),
      });
    }
  });

  useEffect(() => {
    if (!conversationQuery.data) {
      return;
    }

    if (conversationQuery.data.adminUnreadCount > 0 && !markReadRequestRef.current) {
      markReadRequestRef.current = markSupportConversationRead(conversationId)
        .then(refreshConversationData)
        .catch(() => undefined)
        .finally(() => {
          markReadRequestRef.current = null;
        });
    }
  }, [conversationId, conversationQuery.data, refreshConversationData]);

  const sendMutation = useMutation({
    mutationFn: async () =>
      selectedAttachment
        ? sendSupportAttachment(conversationId, selectedAttachment, reply.trim())
        : sendSupportMessage(conversationId, reply.trim()),
    onSuccess: async () => {
      setReply("");
      resetSelectedAttachment();
      setToast({ type: "success", message: text.supportReplySent });
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
    },
  });

  const statusMutation = useMutation({
    mutationFn: async (status: SupportConversationStatus) =>
      updateSupportConversationStatus(conversationId, status),
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportStatusSaved });
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
    },
  });

  const assignmentMutation = useMutation({
    mutationFn: async (assignedAdminId?: string | null) =>
      assignSupportConversation(conversationId, assignedAdminId),
    onSuccess: async () => {
      setToast({ type: "success", message: text.supportAssignmentSaved });
      await refreshConversationData();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
    },
  });

  const templateSaveMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        title: templateDraft.title.trim(),
        body: templateDraft.body.trim(),
        isEnabled: templateDraft.isEnabled,
        sortOrder: templateDraft.sortOrder,
      };

      return templateDraft.templateId
        ? updateSupportReplyTemplate(templateDraft.templateId, payload)
        : createSupportReplyTemplate(payload);
    },
    onSuccess: async (savedTemplate) => {
      setTemplateDraft(emptyTemplateDraft);
      setSelectedTemplateId(savedTemplate.templateId);
      setIsTemplateEditorOpen(false);
      setToast({ type: "success", message: text.supportTemplateSaved });
      await refreshTemplateCatalog();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
    },
  });

  const templateDeleteMutation = useMutation({
    mutationFn: async (templateId: string) => deleteSupportReplyTemplate(templateId),
    onSuccess: async () => {
      setTemplateDraft(emptyTemplateDraft);
      setSelectedTemplateId(null);
      setIsTemplateEditorOpen(false);
      setToast({ type: "success", message: text.supportTemplateDeleted });
      await refreshTemplateCatalog();
    },
    onError: () => {
      setToast({ type: "error", message: text.supportLoadError });
    },
  });

  const conversation = conversationQuery.data;
  const sessionUserId = session?.user.userId ?? null;
  const isAssignedToCurrentAdmin = Boolean(
    sessionUserId && conversation?.assignedAdminId === sessionUserId
  );
  const subjectUserId = conversation?.initiatorUserId ?? null;

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
    queryFn: () => fetchAdminEconomyPurchasesForUser(subjectUserId!),
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
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return haystacks.includes(normalizedQuery);
    });
  }, [inboxItems, searchQuery]);

  const sortedTemplates = useMemo(
    () =>
      (templatesQuery.data ?? []).slice().sort((left, right) => {
        if (left.sortOrder !== right.sortOrder) {
          return left.sortOrder - right.sortOrder;
        }

        return left.title.localeCompare(right.title, locale === "ru" ? "ru" : "en");
      }),
    [locale, templatesQuery.data]
  );

  const filteredTemplates = useMemo(() => {
    const normalizedQuery = templateSearchQuery.trim().toLowerCase();

    return sortedTemplates.filter((template) => {
      if (!normalizedQuery) {
        return true;
      }

      return `${template.title} ${template.body}`.toLowerCase().includes(normalizedQuery);
    });
  }, [sortedTemplates, templateSearchQuery]);

  const visibleTemplates = useMemo(
    () => sortedTemplates.filter((template) => template.isEnabled).slice(0, 4),
    [sortedTemplates]
  );

  const composerValue = reply;
  const composerPlaceholder = text.supportReplyPlaceholder;
  const userDisplayName =
    conversation?.userDisplayName?.trim() ||
    conversation?.userEmail ||
    text.supportConversationTitle;
  const hasComposerAttachment = selectedAttachment !== null;

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

  const selectedTemplate =
    filteredTemplates.find((template) => template.templateId === selectedTemplateId) ??
    filteredTemplates[0] ??
    null;

  const accountCreatedAt = userQuery.data?.createdAtUtc ?? conversation?.createdAtUtc ?? null;
  const conversationWaitingSince =
    conversation?.lastMessageAtUtc ?? conversation?.createdAtUtc ?? null;
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

  const applyTemplate = useCallback((template: AdminSupportReplyTemplate) => {
    setSelectedTemplateId(template.templateId);
    setReply((current) => mergeTemplateDraft(current, template.body));
  }, []);

  const openTemplateEditor = useCallback((template?: AdminSupportReplyTemplate) => {
    if (template) {
      setSelectedTemplateId(template.templateId);
      setTemplateDraft({
        templateId: template.templateId,
        title: template.title,
        body: template.body,
        isEnabled: template.isEnabled,
        sortOrder: template.sortOrder,
      });
      setIsTemplateEditorOpen(true);
      return;
    }

    setTemplateDraft({
      ...emptyTemplateDraft,
    });
    setSelectedTemplateId(null);
    setIsTemplateEditorOpen(true);
  }, []);

  return {
    activeSidePanelTab,
    accountCreatedAt,
    activityTimeline,
    analyticsQuery,
    applyTemplate,
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
    filteredTemplates,
    hasComposerAttachment,
    inboxQuery,
    isAssignedToCurrentAdmin,
    isSidePanelOpen,
    isTemplateEditorOpen,
    openTemplateEditor,
    primaryStatusAction,
    purchasesQuery,
    recentUserPurchases,
    lastUserPurchaseAtUtc,
    lastActivityAtUtc,
    recentFailures,
    reply,
    resetSelectedAttachment,
    searchQuery,
    selectedAttachment,
    selectedTemplate,
    secondaryStatusActions,
    sendMutation,
    sessionUserId,
    setActiveSidePanelTab,
    setIsSidePanelOpen,
    setIsTemplateEditorOpen,
    setReply,
    setSearchQuery,
    setAssignmentFilter,
    setSelectedAttachment,
    setSelectedTemplateId,
    setStatusFilter,
    setTemplateDraft,
    setTemplateSearchQuery,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    statusFilter,
    assignmentFilter,
    statusMutation,
    templateDeleteMutation,
    templateDraft,
    templateSaveMutation,
    templateSearchQuery,
    templatesQuery,
    text,
    toast,
    totalPurchases,
    userDisplayName,
    userQuery,
    visibleTemplates,
  };
}

async function fetchAdminEconomyPurchasesForUser(userId: string): Promise<AdminEconomyPurchase[]> {
  const take = 100;
  const maxPages = 8;
  const matches: AdminEconomyPurchase[] = [];

  for (let page = 0; page < maxPages; page += 1) {
    const response = await fetchAdminEconomyPurchases({ skip: page * take, take });
    matches.push(...response.items.filter((item) => item.userId === userId));

    if (!response.hasMore) {
      break;
    }
  }

  return matches.sort((left, right) => {
    const leftTime = Date.parse(left.confirmedAtUtc ?? left.createdAtUtc);
    const rightTime = Date.parse(right.confirmedAtUtc ?? right.createdAtUtc);
    return rightTime - leftTime;
  });
}
