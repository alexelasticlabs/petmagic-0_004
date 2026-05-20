"use client";

import { AdminBadge, AdminCard, AdminPage, AdminSelectField, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    fetchAdminUser,
    fetchAdminUserAnalytics,
    assignSupportConversation,
    createSupportReplyTemplate,
    fetchSupportInbox,
    deleteSupportReplyTemplate,
    fetchSupportConversation,
    fetchSupportReplyTemplates,
    markSupportConversationRead,
    sendSupportInternalNote,
    sendSupportMessage,
    updateSupportConversationStatus,
    updateSupportReplyTemplate,
    useAuthSession,
    type AdminSupportConversation,
    type AdminSupportConversationSummary,
    type AdminUserAnalytics,
    type AdminUserDetail,
    type AdminSupportReplyTemplate,
    type SupportConversationStatus,
    type SupportReplyTemplateKind,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import styles from "@/components/support/support-page.module.css";

type SupportConversationPageProps = {
    locale: Locale;
    conversationId: string;
};

type ToastState = {
    type: "success" | "error";
    message: string;
};

type SupportFilter = "all" | SupportConversationStatus;
type TemplateKindFilter = "all" | SupportReplyTemplateKind;

type ComposerMode = "reply" | "note";
type SidePanelTab = "user" | "templates" | "history";

type TimelineItem = {
    id: string;
    title: string;
    subtitle: string;
    occurredAtUtc: string;
    tone: "neutral" | "primary" | "info" | "success" | "warning" | "danger";
};

type TemplateDraft = {
    templateId: string | null;
    title: string;
    body: string;
    kind: SupportReplyTemplateKind;
    isEnabled: boolean;
    sortOrder: number;
};

const statusOptions: SupportConversationStatus[] = ["Open", "InProgress", "Resolved", "Closed"];
const emptyTemplateDraft: TemplateDraft = {
    templateId: null,
    title: "",
    body: "",
    kind: "Reply",
    isEnabled: true,
    sortOrder: 0,
};

export function SupportConversationPage({ locale, conversationId }: SupportConversationPageProps) {
    const text = getDictionary(locale);
    const router = useRouter();
    const session = useAuthSession();
    const queryClient = useQueryClient();
    const [statusFilter, setStatusFilter] = useState<SupportFilter>("all");
    const [searchQuery, setSearchQuery] = useState("");
    const [reply, setReply] = useState("");
    const [internalNote, setInternalNote] = useState("");
    const [composerMode, setComposerMode] = useState<ComposerMode>("reply");
    const [templateDraft, setTemplateDraft] = useState<TemplateDraft>(emptyTemplateDraft);
    const [templateFilter, setTemplateFilter] = useState<TemplateKindFilter>("all");
    const [templateSearchQuery, setTemplateSearchQuery] = useState("");
    const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
    const [isTemplateEditorOpen, setIsTemplateEditorOpen] = useState(false);
    const [activeSidePanelTab, setActiveSidePanelTab] = useState<SidePanelTab>("user");
    const [isSidePanelOpen, setIsSidePanelOpen] = useState(false);
    const [toast, setToast] = useState<ToastState | null>(null);

    const refreshConversationData = useCallback(async () => {
        await Promise.all([
            queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportConversation(conversationId) }),
            queryClient.invalidateQueries({ queryKey: ["admin", "support", "inbox"] }),
        ]);
    }, [conversationId, queryClient]);

    const refreshTemplateCatalog = async () => {
        await queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportTemplates });
    };

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

    const conversationQuery = useQuery<AdminSupportConversation>({
        queryKey: adminQueryKeys.supportConversation(conversationId),
        queryFn: () => fetchSupportConversation(conversationId),
        enabled: Boolean(session),
    });

    const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
        queryKey: adminQueryKeys.supportInbox(statusFilter, "all"),
        queryFn: () => fetchSupportInbox(statusFilter === "all" ? undefined : statusFilter, "all"),
        enabled: Boolean(session),
    });

    const templatesQuery = useQuery<AdminSupportReplyTemplate[]>({
        queryKey: adminQueryKeys.supportTemplates,
        queryFn: () => fetchSupportReplyTemplates(),
        enabled: Boolean(session),
    });

    useSupportRealtime(session?.accessToken, (event) => {
        void queryClient.invalidateQueries({ queryKey: ["admin", "support", "inbox"] });
        if (event.conversationId === conversationId) {
            void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportConversation(conversationId) });
        }
    });

    useEffect(() => {
        if (!conversationQuery.data) {
            return;
        }

        if (conversationQuery.data.adminUnreadCount > 0) {
            void markSupportConversationRead(conversationId)
                .then(refreshConversationData)
                .catch(() => undefined);
        }
    }, [conversationId, conversationQuery.data, refreshConversationData]);

    const sendMutation = useMutation({
        mutationFn: async () => sendSupportMessage(conversationId, reply.trim()),
        onSuccess: async () => {
            setReply("");
            setToast({ type: "success", message: text.supportReplySent });
            await refreshConversationData();
        },
        onError: () => {
            setToast({ type: "error", message: text.supportLoadError });
        },
    });

    const noteMutation = useMutation({
        mutationFn: async () => sendSupportInternalNote(conversationId, internalNote.trim()),
        onSuccess: async () => {
            setInternalNote("");
            setToast({ type: "success", message: text.supportInternalNoteSaved });
            await refreshConversationData();
        },
        onError: () => {
            setToast({ type: "error", message: text.supportLoadError });
        },
    });

    const statusMutation = useMutation({
        mutationFn: async (status: SupportConversationStatus) => updateSupportConversationStatus(conversationId, status),
        onSuccess: async () => {
            setToast({ type: "success", message: text.supportStatusSaved });
            await refreshConversationData();
        },
        onError: () => {
            setToast({ type: "error", message: text.supportLoadError });
        },
    });

    const assignmentMutation = useMutation({
        mutationFn: async (assignedAdminId?: string | null) => assignSupportConversation(conversationId, assignedAdminId),
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
                kind: templateDraft.kind,
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
    const isAssignedToCurrentAdmin = Boolean(sessionUserId && conversation?.assignedAdminId === sessionUserId);
    const subjectUserId = conversation?.initiatorUserId ?? null;
    const userQuery = useQuery<AdminUserDetail>({
        queryKey: ["admin", "users", subjectUserId],
        queryFn: () => fetchAdminUser(subjectUserId!),
        enabled: Boolean(session && subjectUserId),
    });
    const analyticsQuery = useQuery<AdminUserAnalytics>({
        queryKey: ["admin", "users", subjectUserId, "analytics"],
        queryFn: () => fetchAdminUserAnalytics(subjectUserId!),
        enabled: Boolean(session && subjectUserId),
    });
    const inboxItems = useMemo(() => inboxQuery.data ?? [], [inboxQuery.data]);
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
                if (left.kind !== right.kind) {
                    return left.kind === "Reply" ? -1 : 1;
                }

                if (left.sortOrder !== right.sortOrder) {
                    return left.sortOrder - right.sortOrder;
                }

                return left.title.localeCompare(right.title, locale === "ru" ? "ru" : "en");
            }),
        [locale, templatesQuery.data],
    );
    const filteredTemplates = useMemo(() => {
        const normalizedQuery = templateSearchQuery.trim().toLowerCase();

        return sortedTemplates.filter((template) => {
            if (templateFilter !== "all" && template.kind !== templateFilter) {
                return false;
            }

            if (!normalizedQuery) {
                return true;
            }

            return `${template.title} ${template.body}`.toLowerCase().includes(normalizedQuery);
        });
    }, [sortedTemplates, templateFilter, templateSearchQuery]);
    const visibleTemplates = useMemo(
        () =>
            sortedTemplates
                .filter((template) => template.isEnabled && template.kind === (composerMode === "reply" ? "Reply" : "InternalNote"))
                .slice(0, 4),
        [composerMode, sortedTemplates],
    );
    const composerValue = composerMode === "reply" ? reply : internalNote;
    const composerPlaceholder = composerMode === "reply" ? text.supportReplyPlaceholder : text.supportInternalNotePlaceholder;
    const userDisplayName = conversation?.userDisplayName?.trim() || conversation?.userEmail || text.supportConversationTitle;
    const selectedTemplate = filteredTemplates.find((template) => template.templateId === selectedTemplateId) ?? filteredTemplates[0] ?? null;
    const lastCountry = analyticsQuery.data?.recentTemplateEvents[0]?.countryCode || "—";
    const lastPurchase = analyticsQuery.data?.recentPurchases[0] ?? null;
    const conversationTimeline = useMemo(() => {
        if (!conversation) {
            return [] as TimelineItem[];
        }

        const items: TimelineItem[] = [
            {
                id: `conversation:${conversation.conversationId}`,
                title: text.supportTimelineConversationCreated,
                subtitle: userDisplayName,
                occurredAtUtc: conversation.createdAtUtc,
                tone: "info",
            },
            ...conversation.messages.map((message) => ({
                id: message.messageId,
                title: message.isInternalNote
                    ? text.supportTimelineInternalNote
                    : message.isFromAdmin
                        ? text.supportTimelineAdminReply
                        : text.supportTimelineUserMessage,
                subtitle: `${message.senderDisplayName} • ${truncateText(message.body, 112)}`,
                occurredAtUtc: message.createdAtUtc,
                tone: message.isInternalNote ? "warning" as const : message.isFromAdmin ? "success" as const : "primary" as const,
            })),
        ];

        return items.sort((left, right) => new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime());
    }, [conversation, text.supportTimelineAdminReply, text.supportTimelineConversationCreated, text.supportTimelineInternalNote, text.supportTimelineUserMessage, userDisplayName]);

    const applyTemplate = useCallback((template: AdminSupportReplyTemplate) => {
        setSelectedTemplateId(template.templateId);

        if (template.kind === "Reply") {
            setComposerMode("reply");
            setReply((current) => mergeTemplateDraft(current, template.body));
            return;
        }

        setComposerMode("note");
        setInternalNote((current) => mergeTemplateDraft(current, template.body));
    }, []);

    const openTemplateEditor = useCallback((template?: AdminSupportReplyTemplate) => {
        if (template) {
            setSelectedTemplateId(template.templateId);
            setTemplateDraft({
                templateId: template.templateId,
                title: template.title,
                body: template.body,
                kind: template.kind,
                isEnabled: template.isEnabled,
                sortOrder: template.sortOrder,
            });
            setIsTemplateEditorOpen(true);
            return;
        }

        setTemplateDraft({
            ...emptyTemplateDraft,
            kind: composerMode === "reply" ? "Reply" : "InternalNote",
        });
        setSelectedTemplateId(null);
        setIsTemplateEditorOpen(true);
    }, [composerMode]);

    return (
        <AdminPage className={styles.page}>
            {toast ? <Toast type={toast.type} message={toast.message} /> : null}

            {conversationQuery.isLoading ? (
                <AdminStateCard tone="info" title={text.loading} description={text.supportConversationDescription} />
            ) : conversationQuery.isError || !conversation ? (
                <AdminStateCard
                    tone="danger"
                    title={text.supportLoadError}
                    action={<Link href={`/${locale}/support`} className="ui-button ui-button--secondary ui-button--md">{text.supportBackToInbox}</Link>}
                />
            ) : (
                <>
                    <div className={styles.compactHeader}>
                        <div className={styles.compactHeaderTrail}>
                            <Link href={`/${locale}/support`} className={styles.compactHeaderLink}>{text.supportTitle}</Link>
                            <span className={styles.compactHeaderSeparator}>/</span>
                            <strong>{shortId(conversation.conversationId)}</strong>
                            <span className={styles.subtle}>{userDisplayName}</span>
                        </div>
                        <div className={styles.compactHeaderMeta}>
                            <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                            <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                            {conversation.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{conversation.adminUnreadCount}</span> : null}
                            <Button variant="secondary" size="sm" onClick={() => setIsSidePanelOpen((current) => !current)}>
                                {isSidePanelOpen ? text.supportClosePanelAction : text.supportOpenPanelAction}
                            </Button>
                        </div>
                    </div>

                    <div className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceWithSidebar : styles.workspaceCompact}`}>
                        <AdminCard title={text.supportInboxTitle} description={text.supportInboxDescription} className={styles.inboxPane}>
                            <div className={styles.inboxToolbar}>
                                <div className={styles.statusSelect}>
                                    <AdminSelectField
                                        label={text.statusLabel}
                                        value={statusFilter}
                                        options={[
                                            { value: "all", label: text.supportStatusAll },
                                            ...statusOptions.map((status) => ({ value: status, label: statusLabel(status, text) })),
                                        ]}
                                        onChange={(value) => setStatusFilter(value as SupportFilter)}
                                    />
                                </div>
                                <label className={styles.searchField}>
                                    <span className={styles.searchLabel}>{text.supportSearchPlaceholder}</span>
                                    <input
                                        className={styles.searchInput}
                                        value={searchQuery}
                                        onChange={(event) => setSearchQuery(event.target.value)}
                                        placeholder={text.supportSearchPlaceholder}
                                    />
                                </label>
                            </div>

                            {inboxQuery.isLoading ? (
                                <AdminStateCard tone="info" title={text.loading} />
                            ) : inboxQuery.isError ? (
                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                            ) : filteredInboxItems.length === 0 ? (
                                <AdminStateCard tone="info" title={text.supportEmpty} />
                            ) : (
                                <div className={styles.list}>
                                    {filteredInboxItems.map((item) => (
                                        <Link
                                            key={item.conversationId}
                                            href={`/${locale}/support/${item.conversationId}`}
                                            className={`${styles.conversationRow} ${item.conversationId === conversationId ? styles.conversationRowActive : ""}`}
                                        >
                                            <div className={styles.rowHeader}>
                                                <div className={styles.rowIdentity}>
                                                    <span className={styles.avatar}>{initialsFor(item.userDisplayName?.trim() || item.userEmail)}</span>
                                                    <div>
                                                        <div className={styles.rowTitle}>{item.userDisplayName?.trim() || item.userEmail}</div>
                                                        <div className={styles.subtle}>{item.userEmail}</div>
                                                    </div>
                                                </div>
                                                <span className={styles.timePill}>{formatRelativeTime(item.lastMessageAtUtc ?? item.updatedAtUtc, locale)}</span>
                                            </div>
                                            <div className={styles.rowPreview}>{item.lastMessagePreview || text.supportNoMessages}</div>
                                            <div className={styles.rowFooter}>
                                                <div className={styles.rowMetaGroup}>
                                                    <AdminBadge tone={priorityTone(item.priority)}>{priorityLabel(item.priority, text)}</AdminBadge>
                                                    <AdminBadge tone={toneForStatus(item.status)}>{statusLabel(item.status, text)}</AdminBadge>
                                                    {item.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{item.adminUnreadCount}</span> : null}
                                                </div>
                                                <span className={styles.waitingLabel}>{`${text.supportWaitingLabel}: ${formatWaitTime(item.lastMessageAtUtc ?? item.createdAtUtc, locale)}`}</span>
                                            </div>
                                        </Link>
                                    ))}
                                </div>
                            )}
                        </AdminCard>

                        <div className={styles.chatPane}>
                            <AdminCard className={styles.chatShell}>
                                <div className={styles.chatTopbar}>
                                    <div className={styles.chatIdentityCompact}>
                                        <div className={styles.chatTitleRow}>
                                            <strong className={styles.chatUserName}>{userDisplayName}</strong>
                                            <span className={styles.onlineDot} />
                                        </div>
                                        <div className={styles.chatMetaLine}>
                                            <span>{conversation.userEmail}</span>
                                            <span>•</span>
                                            <span>{shortId(conversation.initiatorUserId)}</span>
                                            <span>•</span>
                                            <span>{`${text.supportAssignedTo}: ${conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}`}</span>
                                        </div>
                                    </div>

                                    <div className={styles.chatActionsBar}>
                                        <span className={styles.waitingLabel}>{`${text.supportWaitingLabel}: ${formatWaitTime(conversation.lastMessageAtUtc ?? conversation.createdAtUtc, locale)}`}</span>
                                        <div className={styles.chatStatusControls}>
                                            <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                                            <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                            <div className={styles.statusSelectCompact}>
                                                <AdminSelectField
                                                    label={text.statusLabel}
                                                    value={conversation.status}
                                                    options={statusOptions.map((status) => ({ value: status, label: statusLabel(status, text) }))}
                                                    onChange={(value) => {
                                                        const nextStatus = value as SupportConversationStatus;
                                                        if (nextStatus === conversation.status) {
                                                            return;
                                                        }

                                                        statusMutation.mutate(nextStatus);
                                                    }}
                                                />
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {conversation.messages.length > 0 ? (
                                    <div className={styles.messagesWrap}>
                                        <div className={styles.dayDivider}>{text.supportTodayLabel}</div>
                                        <div className={styles.messages}>
                                            {conversation.messages.map((message) => (
                                                <article
                                                    key={message.messageId}
                                                    className={`${styles.messageItem} ${message.isInternalNote ? styles.messageNote : message.isFromAdmin ? styles.messageAdmin : styles.messageUser}`}
                                                >
                                                    <div className={styles.messageHeader}>
                                                        <div className={styles.messageSenderWrap}>
                                                            {!message.isFromAdmin && !message.isInternalNote ? <span className={styles.avatarTiny}>{initialsFor(message.senderDisplayName)}</span> : null}
                                                            <strong>{message.senderDisplayName}</strong>
                                                        </div>
                                                        <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                                                    </div>
                                                    <div className={styles.messageBody}>{message.body}</div>
                                                    {message.isInternalNote ? <AdminBadge tone="warning">{text.supportInternalNoteBadge}</AdminBadge> : null}
                                                </article>
                                            ))}
                                        </div>
                                    </div>
                                ) : (
                                    <AdminStateCard tone="info" title={text.supportNoMessages} />
                                )}

                                <div className={styles.composerShell}>
                                    <div className={styles.composerTabs}>
                                        <button
                                            type="button"
                                            className={`${styles.composerTab} ${composerMode === "reply" ? styles.composerTabActive : ""}`}
                                            onClick={() => setComposerMode("reply")}
                                        >
                                            {text.supportReplyAction}
                                        </button>
                                        <button
                                            type="button"
                                            className={`${styles.composerTab} ${composerMode === "note" ? styles.composerTabActive : ""}`}
                                            onClick={() => setComposerMode("note")}
                                        >
                                            {text.supportInternalNoteAction}
                                        </button>
                                    </div>

                                    {visibleTemplates.length > 0 ? (
                                        <div className={styles.composerTemplateRail}>
                                            <span className={styles.subtle}>
                                                {composerMode === "reply" ? text.supportQuickRepliesLabel : text.supportInternalNoteTemplatesLabel}
                                            </span>
                                            <div className={styles.templateList}>
                                                {visibleTemplates.map((template) => (
                                                    <Button
                                                        key={template.templateId}
                                                        size="sm"
                                                        variant="ghost"
                                                        className={styles.quickTemplateButton}
                                                        onClick={() => applyTemplate(template)}
                                                    >
                                                        {`/${template.title}`}
                                                    </Button>
                                                ))}
                                            </div>
                                        </div>
                                    ) : null}

                                    <textarea
                                        className={styles.textarea}
                                        value={composerValue}
                                        onChange={(event) => {
                                            if (composerMode === "reply") {
                                                setReply(event.target.value);
                                                return;
                                            }

                                            setInternalNote(event.target.value);
                                        }}
                                        placeholder={composerPlaceholder}
                                    />

                                    <div className={styles.composerActions}>
                                        <div className={styles.composerContextHint}>
                                            <span className={styles.subtle}>{`${text.supportMessagesCount}: ${conversation.messages.length}`}</span>
                                            <span className={styles.subtle}>{`${text.supportUnreadAdmin}: ${conversation.adminUnreadCount}`}</span>
                                            <span className={styles.subtle}>{`${text.supportUnreadUser}: ${conversation.userUnreadCount}`}</span>
                                        </div>
                                        <div className={styles.rowMetaGroup}>
                                            <Button
                                                variant="primary"
                                                onClick={() => composerMode === "reply" ? sendMutation.mutate() : noteMutation.mutate()}
                                                disabled={
                                                    composerMode === "reply"
                                                        ? sendMutation.isPending || !reply.trim()
                                                        : noteMutation.isPending || !internalNote.trim()
                                                }
                                            >
                                                {composerMode === "reply"
                                                    ? (sendMutation.isPending ? text.supportReplySending : text.supportReplyAction)
                                                    : (noteMutation.isPending ? text.loading : text.supportInternalNoteAction)}
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            </AdminCard>
                        </div>

                        {isSidePanelOpen ? <div className={styles.sidePane}>
                            <AdminCard
                                title={activeSidePanelTab === "user" ? text.supportUserInformationTitle : activeSidePanelTab === "templates" ? text.supportTemplatesManagerTitle : text.supportViewHistoryTab}
                                description={activeSidePanelTab === "templates" ? text.supportTemplatesManagerDescription : undefined}
                                className={`${styles.sideCard} ${styles.sidePanelCard}`}
                                action={
                                    <div className={styles.sidePanelTabs}>
                                        {([
                                            ["user", text.supportViewUserTab],
                                            ["templates", text.supportViewTemplatesTab],
                                            ["history", text.supportViewHistoryTab],
                                        ] as const).map(([value, label]) => (
                                            <button
                                                key={value}
                                                type="button"
                                                className={`${styles.sidePanelTab} ${activeSidePanelTab === value ? styles.sidePanelTabActive : ""}`}
                                                onClick={() => setActiveSidePanelTab(value)}
                                            >
                                                {label}
                                            </button>
                                        ))}
                                    </div>
                                }
                            >
                                {activeSidePanelTab === "user" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.userSummaryHeader}>
                                            <div className={styles.userCard}>
                                                <span className={styles.avatarHero}>{initialsFor(userDisplayName)}</span>
                                                <div className={styles.userCardBody}>
                                                    <strong>{userDisplayName}</strong>
                                                    <span>{conversation.userEmail}</span>
                                                    <span>{`User ID: ${shortId(conversation.initiatorUserId)}`}</span>
                                                </div>
                                            </div>
                                            <Link href={`/${locale}/users/${conversation.initiatorUserId}`} className="ui-button ui-button--secondary ui-button--sm">
                                                {text.userOpenFullProfile}
                                            </Link>
                                        </div>

                                        <div className={styles.rowMetaGroup}>
                                            <AdminBadge tone={userQuery.data?.isPremium ? "warning" : "neutral"}>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</AdminBadge>
                                            <AdminBadge tone={userQuery.data?.isActive === false ? "danger" : "success"}>{userQuery.data?.isActive === false ? text.noLabel : text.activeLabel}</AdminBadge>
                                            <AdminBadge tone={userQuery.data?.emailConfirmed ? "info" : "neutral"}>{userQuery.data?.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}</AdminBadge>
                                        </div>

                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportPlanLabel}</span><strong>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</strong></div>
                                            <div className={styles.metricTile}><span>{text.tokenBalanceLabel}</span><strong>{analyticsQuery.data ? String(analyticsQuery.data.summary.walletBalance) : "—"}</strong></div>
                                            <div className={styles.metricTile}><span>{text.completedGenerationsLabel}</span><strong>{analyticsQuery.data ? String(analyticsQuery.data.summary.completedGenerations) : "—"}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastGenerationLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastPaymentLabel}</span><strong>{lastPurchase ? formatMoney(lastPurchase.priceAmount, lastPurchase.currencyCode, locale) : "—"}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportCountryLabel}</span><strong>{lastCountry}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastSeenLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastActivityAtUtc, locale)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportMessagesCount}</span><strong>{String(conversation.messages.length)}</strong></div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportActionsTitle}</strong>
                                            </div>
                                            <div className={styles.actionListCompact}>
                                                <Button
                                                    variant="secondary"
                                                    onClick={() => assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)}
                                                    disabled={assignmentMutation.isPending || !sessionUserId}
                                                >
                                                    {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                                                </Button>
                                                <Button
                                                    variant="danger"
                                                    onClick={() => statusMutation.mutate("Closed")}
                                                    disabled={statusMutation.isPending || conversation.status === "Closed"}
                                                >
                                                    {text.supportCloseConversationAction}
                                                </Button>
                                            </div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportAiContextTitle}</strong>
                                            </div>
                                            {analyticsQuery.isLoading ? (
                                                <AdminStateCard tone="info" title={text.loading} />
                                            ) : analyticsQuery.isError ? (
                                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                                            ) : analyticsQuery.data?.recentGenerations.length ? (
                                                <div className={styles.timelineList}>
                                                    {analyticsQuery.data.recentGenerations.slice(0, 4).map((generation) => (
                                                        <article key={generation.generationId} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{generation.templateTitle}</strong>
                                                                <span>{formatRelativeTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}</span>
                                                            </div>
                                                            <div className={styles.rowMetaGroup}>
                                                                <AdminBadge tone={toneForGeneration(generation.status)}>{generation.status}</AdminBadge>
                                                                <span className={styles.subtle}>{`${generation.tokenCost} spark`}</span>
                                                            </div>
                                                            {generation.failureMessage ? <p className={styles.timelineCardBody}>{generation.failureMessage}</p> : null}
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.userNoGenerations} />
                                            )}
                                        </div>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "templates" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.templateCatalogControls}>
                                            <label className={styles.searchField}>
                                                <span className={styles.searchLabel}>{text.supportTemplateSearchPlaceholder}</span>
                                                <input
                                                    className={styles.searchInput}
                                                    value={templateSearchQuery}
                                                    onChange={(event) => setTemplateSearchQuery(event.target.value)}
                                                    placeholder={text.supportTemplateSearchPlaceholder}
                                                />
                                            </label>
                                            <div className={styles.templateToolbarCompact}>
                                                <div className={styles.templateFilterChips}>
                                                    {([
                                                        ["all", text.supportTemplateFilterAll],
                                                        ["Reply", text.supportTemplateKindReply],
                                                        ["InternalNote", text.supportTemplateKindInternalNote],
                                                    ] as const).map(([value, label]) => (
                                                        <button
                                                            key={value}
                                                            type="button"
                                                            className={`${styles.templateFilterChip} ${templateFilter === value ? styles.templateFilterChipActive : ""}`}
                                                            onClick={() => setTemplateFilter(value)}
                                                        >
                                                            {label}
                                                        </button>
                                                    ))}
                                                </div>
                                                <Button size="sm" variant="secondary" onClick={() => openTemplateEditor()}>
                                                    {text.supportTemplateCreateAction}
                                                </Button>
                                            </div>
                                        </div>

                                        {templatesQuery.isLoading ? (
                                            <AdminStateCard tone="info" title={text.loading} />
                                        ) : templatesQuery.isError ? (
                                            <AdminStateCard tone="danger" title={text.supportLoadError} />
                                        ) : filteredTemplates.length === 0 ? (
                                            <AdminStateCard tone="info" title={text.supportTemplateNoTemplates} />
                                        ) : (
                                            <>
                                                <div className={styles.templateCatalogList}>
                                                    {filteredTemplates.map((template) => (
                                                        <button
                                                            key={template.templateId}
                                                            type="button"
                                                            className={`${styles.templateListItem} ${selectedTemplate?.templateId === template.templateId ? styles.templateListItemActive : ""}`}
                                                            onClick={() => setSelectedTemplateId(template.templateId)}
                                                        >
                                                            <div className={styles.templateListItemHeader}>
                                                                <div className={styles.templateTitleStack}>
                                                                    <strong className={styles.rowTitle}>{template.title}</strong>
                                                                    <span className={styles.subtle}>{`${text.supportUpdatedLabel}: ${formatRelativeTime(template.updatedAtUtc, locale)}`}</span>
                                                                </div>
                                                                <div className={styles.rowMetaGroup}>
                                                                    <AdminBadge tone={template.kind === "Reply" ? "primary" : "warning"}>
                                                                        {template.kind === "Reply" ? text.supportTemplateKindReply : text.supportTemplateKindInternalNote}
                                                                    </AdminBadge>
                                                                    {!template.isEnabled ? <AdminBadge tone="neutral">{text.supportTemplateDisabledBadge}</AdminBadge> : null}
                                                                </div>
                                                            </div>
                                                            <div className={styles.templateSnippet}>{template.body}</div>
                                                        </button>
                                                    ))}
                                                </div>

                                                {selectedTemplate ? (
                                                    <div className={styles.templateDetailPane}>
                                                        <div className={styles.templatePreviewHeader}>
                                                            <div className={styles.templateTitleStack}>
                                                                <strong className={styles.chatUserName}>{selectedTemplate.title}</strong>
                                                                <span className={styles.subtle}>{`${text.supportUpdatedLabel}: ${formatDateTime(selectedTemplate.updatedAtUtc, locale)}`}</span>
                                                            </div>
                                                            <div className={styles.templateRowActions}>
                                                                <Button size="sm" variant="primary" onClick={() => applyTemplate(selectedTemplate)}>
                                                                    {text.supportTemplateUseAction}
                                                                </Button>
                                                                <Button size="sm" variant="secondary" onClick={() => openTemplateEditor(selectedTemplate)}>
                                                                    {text.supportTemplateEditAction}
                                                                </Button>
                                                                <Button
                                                                    size="sm"
                                                                    variant="danger"
                                                                    onClick={() => templateDeleteMutation.mutate(selectedTemplate.templateId)}
                                                                    disabled={templateDeleteMutation.isPending}
                                                                >
                                                                    {text.supportTemplateDeleteAction}
                                                                </Button>
                                                            </div>
                                                        </div>
                                                        <div className={styles.templatePreviewBody}>{selectedTemplate.body}</div>
                                                    </div>
                                                ) : null}

                                                {isTemplateEditorOpen ? (
                                                    <div className={styles.templateEditor}>
                                                        <div className={styles.templateEditorHeader}>
                                                            <strong className={styles.chatUserName}>
                                                                {templateDraft.templateId ? text.supportTemplateUpdateAction : text.supportTemplateCreateAction}
                                                            </strong>
                                                            <span className={styles.subtle}>{text.supportTemplatesManagerDescription}</span>
                                                        </div>

                                                        <div className={styles.templateForm}>
                                                            <label className={styles.templateSection}>
                                                                <span className={styles.subtle}>{text.supportTemplateTitleLabel}</span>
                                                                <input
                                                                    className={styles.input}
                                                                    value={templateDraft.title}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, title: event.target.value }))}
                                                                />
                                                            </label>

                                                            <label className={styles.templateSection}>
                                                                <span className={styles.subtle}>{text.supportTemplateBodyLabel}</span>
                                                                <textarea
                                                                    className={styles.textarea}
                                                                    value={templateDraft.body}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, body: event.target.value }))}
                                                                />
                                                            </label>

                                                            <div className={styles.templateFormGrid}>
                                                                <div className={styles.statusSelect}>
                                                                    <AdminSelectField
                                                                        label={text.supportTemplateKindLabel}
                                                                        value={templateDraft.kind}
                                                                        options={[
                                                                            { value: "Reply", label: text.supportTemplateKindReply },
                                                                            { value: "InternalNote", label: text.supportTemplateKindInternalNote },
                                                                        ]}
                                                                        onChange={(value) => setTemplateDraft((current) => ({ ...current, kind: value as SupportReplyTemplateKind }))}
                                                                    />
                                                                </div>

                                                                <label className={styles.templateSection}>
                                                                    <span className={styles.subtle}>{text.supportTemplateSortOrderLabel}</span>
                                                                    <input
                                                                        className={styles.input}
                                                                        type="number"
                                                                        min={0}
                                                                        value={String(templateDraft.sortOrder)}
                                                                        onChange={(event) => setTemplateDraft((current) => ({ ...current, sortOrder: Number(event.target.value) || 0 }))}
                                                                    />
                                                                </label>
                                                            </div>

                                                            <label className={styles.checkboxRow}>
                                                                <input
                                                                    type="checkbox"
                                                                    checked={templateDraft.isEnabled}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, isEnabled: event.target.checked }))}
                                                                />
                                                                <span>{text.supportTemplateEnabledLabel}</span>
                                                            </label>

                                                            <div className={styles.templateRowActions}>
                                                                <Button
                                                                    variant="primary"
                                                                    onClick={() => templateSaveMutation.mutate()}
                                                                    disabled={templateSaveMutation.isPending || !templateDraft.title.trim() || !templateDraft.body.trim()}
                                                                >
                                                                    {templateSaveMutation.isPending
                                                                        ? text.loading
                                                                        : templateDraft.templateId
                                                                            ? text.supportTemplateUpdateAction
                                                                            : text.supportTemplateCreateAction}
                                                                </Button>
                                                                <Button variant="secondary" onClick={() => setTemplateDraft(emptyTemplateDraft)}>
                                                                    {text.supportTemplateResetAction}
                                                                </Button>
                                                                <Button variant="secondary" onClick={() => setIsTemplateEditorOpen(false)}>
                                                                    {text.supportTemplateCancelEditAction}
                                                                </Button>
                                                            </div>
                                                        </div>
                                                    </div>
                                                ) : null}
                                            </>
                                        )}
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "history" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportTimelineTitle}</strong>
                                            </div>
                                            {conversationTimeline.length ? (
                                                <div className={styles.timelineList}>
                                                    {conversationTimeline.map((item) => (
                                                        <article key={item.id} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{item.title}</strong>
                                                                <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                                                            </div>
                                                            <div className={styles.rowMetaGroup}>
                                                                <AdminBadge tone={item.tone}>{formatDateTime(item.occurredAtUtc, locale)}</AdminBadge>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{item.subtitle}</p>
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.supportHistoryEmpty} />
                                            )}
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.userActivityTitle}</strong>
                                            </div>
                                            {analyticsQuery.isLoading ? (
                                                <AdminStateCard tone="info" title={text.loading} />
                                            ) : analyticsQuery.isError ? (
                                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                                            ) : analyticsQuery.data?.recentActivity.length ? (
                                                <div className={styles.timelineList}>
                                                    {analyticsQuery.data.recentActivity.slice(0, 6).map((item) => (
                                                        <article key={`${item.kind}:${item.occurredAtUtc}:${item.title}`} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{item.title}</strong>
                                                                <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{item.details || item.kind}</p>
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.supportHistoryEmpty} />
                                            )}
                                        </div>
                                    </div>
                                ) : null}
                            </AdminCard>
                        </div> : null}
                    </div>
                </>
            )}
        </AdminPage>
    );
}

function statusLabel(status: string, text: ReturnType<typeof getDictionary>) {
    switch (status.toLowerCase()) {
        case "open":
            return text.supportStatusOpen;
        case "inprogress":
            return text.supportStatusInProgress;
        case "resolved":
            return text.supportStatusResolved;
        case "closed":
            return text.supportStatusClosed;
        default:
            return status;
    }
}

function toneForStatus(status: string) {
    switch (status.toLowerCase()) {
        case "open":
            return "warning" as const;
        case "inprogress":
            return "primary" as const;
        case "resolved":
            return "success" as const;
        case "closed":
            return "neutral" as const;
        default:
            return "neutral" as const;
    }
}

function priorityLabel(priority: string, text: ReturnType<typeof getDictionary>) {
    switch (priority.toLowerCase()) {
        case "high":
            return text.supportPriorityHigh;
        case "low":
            return text.supportPriorityLow;
        default:
            return text.supportPriorityNormal;
    }
}

function priorityTone(priority: string) {
    switch (priority.toLowerCase()) {
        case "high":
            return "danger" as const;
        case "low":
            return "neutral" as const;
        default:
            return "success" as const;
    }
}

function toneForGeneration(status: string) {
    switch (status.toLowerCase()) {
        case "completed":
            return "success" as const;
        case "failed":
            return "danger" as const;
        case "processing":
            return "warning" as const;
        default:
            return "info" as const;
    }
}

function formatDateTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
        dateStyle: "medium",
        timeStyle: "short",
    }).format(new Date(value));
}

function formatClockTime(value: string, locale: Locale) {
    return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
        hour: "numeric",
        minute: "2-digit",
    }).format(new Date(value));
}

function formatRelativeTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    const timestamp = new Date(value).getTime();
    const diffMinutes = Math.max(0, Math.round((Date.now() - timestamp) / 60000));
    if (diffMinutes < 1) {
        return locale === "ru" ? "только что" : "just now";
    }

    if (diffMinutes < 60) {
        return locale === "ru" ? `${diffMinutes} мин назад` : `${diffMinutes}m ago`;
    }

    const diffHours = Math.round(diffMinutes / 60);
    if (diffHours < 24) {
        return locale === "ru" ? `${diffHours} ч назад` : `${diffHours}h ago`;
    }

    const diffDays = Math.round(diffHours / 24);
    return locale === "ru" ? `${diffDays} дн назад` : `${diffDays}d ago`;
}

function formatWaitTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    const diffMinutes = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 60000));
    if (diffMinutes < 60) {
        return locale === "ru" ? `${diffMinutes} мин` : `${diffMinutes} min`;
    }

    const diffHours = Math.floor(diffMinutes / 60);
    const restMinutes = diffMinutes % 60;
    if (restMinutes === 0) {
        return locale === "ru" ? `${diffHours} ч` : `${diffHours} h`;
    }

    return locale === "ru" ? `${diffHours} ч ${restMinutes} мин` : `${diffHours} h ${restMinutes} min`;
}

function formatMoney(amount: number, currencyCode: string, locale: Locale) {
    return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
        style: "currency",
        currency: currencyCode,
        maximumFractionDigits: 2,
    }).format(amount);
}

function initialsFor(value: string) {
    return value
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? "")
        .join("") || "PM";
}

function shortId(value: string) {
    return value.length > 8 ? `#${value.slice(0, 8)}` : value;
}

function mergeTemplateDraft(currentValue: string, template: string) {
    const normalizedCurrentValue = currentValue.trim();
    if (!normalizedCurrentValue) {
        return template;
    }

    return `${normalizedCurrentValue}\n\n${template}`;
}

function truncateText(value: string, maxLength: number) {
    if (value.length <= maxLength) {
        return value;
    }

    return `${value.slice(0, maxLength - 1).trimEnd()}…`;
}