"use client";

import { AdminBadge, AdminCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { SupportOptionGroup } from "@/components/support/support-option-group";
import styles from "@/components/support/support-page.module.css";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    assignSupportConversation,
    createSupportReplyTemplate,
    deleteSupportReplyTemplate,
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
    type AdminSupportConversation,
    type AdminSupportConversationSummary,
    type AdminSupportReplyTemplate,
    type AdminUserAnalytics,
    type AdminUserDetail,
    type SupportConversationStatus,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

type SupportConversationPageProps = {
    locale: Locale;
    conversationId: string;
};

type ToastState = {
    type: "success" | "error";
    message: string;
};

type StatusActionDescriptor = {
    status: SupportConversationStatus;
    label: string;
    variant: "primary" | "secondary" | "danger";
};

type SupportFilter = "all" | SupportConversationStatus;
type SidePanelTab = "profile" | "purchases" | "generations" | "errors" | "history" | "templates";

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
    isEnabled: boolean;
    sortOrder: number;
};

const statusOptions: SupportConversationStatus[] = ["Open", "InProgress", "Resolved", "Closed"];
const emptyTemplateDraft: TemplateDraft = {
    templateId: null,
    title: "",
    body: "",
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
    const [templateDraft, setTemplateDraft] = useState<TemplateDraft>(emptyTemplateDraft);
    const [templateSearchQuery, setTemplateSearchQuery] = useState("");
    const [selectedTemplateId, setSelectedTemplateId] = useState<string | null>(null);
    const [isTemplateEditorOpen, setIsTemplateEditorOpen] = useState(false);
    const [activeSidePanelTab, setActiveSidePanelTab] = useState<SidePanelTab>("profile");
    const [isSidePanelOpen, setIsSidePanelOpen] = useState(() => typeof window !== "undefined"
        && window.matchMedia("(min-width: 1321px)").matches);
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
        mutationFn: async () => selectedAttachment
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
            if (!normalizedQuery) {
                return true;
            }

            return `${template.title} ${template.body}`.toLowerCase().includes(normalizedQuery);
        });
    }, [sortedTemplates, templateSearchQuery]);
    const visibleTemplates = useMemo(
        () =>
            sortedTemplates
                .filter((template) => template.isEnabled)
                .slice(0, 4),
        [sortedTemplates],
    );
    const composerValue = reply;
    const composerPlaceholder = text.supportReplyPlaceholder;
    const userDisplayName = conversation?.userDisplayName?.trim() || conversation?.userEmail || text.supportConversationTitle;
    const hasComposerAttachment = selectedAttachment !== null;
    const sidePanelTabs: ReadonlyArray<{ value: SidePanelTab; label: string }> = [
        { value: "profile", label: text.supportViewProfileTab },
        { value: "purchases", label: text.supportViewPurchasesTab },
        { value: "generations", label: text.supportViewGenerationsTab },
        { value: "errors", label: text.supportViewErrorsTab },
        { value: "history", label: text.supportViewHistoryTab },
        { value: "templates", label: text.supportViewTemplatesTab },
    ];
    const sidePanelTitle = activeSidePanelTab === "profile"
        ? text.supportUserInformationTitle
        : activeSidePanelTab === "purchases"
            ? text.supportRecentPurchasesTitle
            : activeSidePanelTab === "generations"
                ? text.supportRecentGenerationsTitle
                : activeSidePanelTab === "errors"
                    ? text.supportGenerationErrorsTitle
                    : activeSidePanelTab === "templates"
                        ? text.supportTemplatesManagerTitle
                        : text.supportTimelineTitle;
    const sidePanelDescription = activeSidePanelTab === "templates"
        ? text.supportTemplatesManagerDescription
        : activeSidePanelTab === "history"
            ? text.supportConversationDescription
            : null;
    const selectedTemplate = filteredTemplates.find((template) => template.templateId === selectedTemplateId) ?? filteredTemplates[0] ?? null;
    const accountCreatedAt = userQuery.data?.createdAtUtc ?? conversation?.createdAtUtc ?? null;
    const conversationWaitingSince = conversation?.lastMessageAtUtc ?? conversation?.createdAtUtc ?? null;
    const conversationSla = getConversationSla(conversationWaitingSince, locale, conversation?.adminUnreadCount ?? 0);
    const totalPurchases = analyticsQuery.data?.summary.totalPurchases ?? 0;
    const failedGenerations = analyticsQuery.data?.recentGenerations.filter((generation) => generation.status.toLowerCase() === "failed") ?? [];
    const recentFailures = analyticsQuery.data?.failureBreakdown.slice(0, 4) ?? [];
    const chatFacts = [
        userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel,
        formatAccountAgeFact(accountCreatedAt, locale),
        formatCountFact(conversation?.messages.length ?? 0, locale, "messages"),
        formatCountFact(totalPurchases, locale, "purchases"),
    ];
    const activityTimeline: TimelineItem[] = [
        ...(analyticsQuery.data?.recentActivity ?? []).slice(0, 4).map((item) => ({
            id: `activity:${item.kind}:${item.occurredAtUtc}:${item.title}`,
            title: item.title,
            subtitle: item.details || item.kind,
            occurredAtUtc: item.occurredAtUtc,
            tone: "info" as const,
        })),
        ...(analyticsQuery.data?.recentAuditEvents ?? []).slice(0, 4).map((item) => ({
            id: `audit:${item.auditEventId}`,
            title: item.action,
            subtitle: item.details,
            occurredAtUtc: item.occurredAtUtc,
            tone: "warning" as const,
        })),
    ].sort((left, right) => new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime());
    const availableStatusActions = conversation ? getAvailableStatusActions(conversation.status, text) : [];
    const primaryStatusAction = availableStatusActions.find((action) => action.variant === "primary") ?? null;
    const secondaryStatusActions = availableStatusActions.filter((action) => action.variant === "secondary");
    const destructiveStatusAction = availableStatusActions.find((action) => action.variant === "danger") ?? null;
    const conversationTimeline: TimelineItem[] = !conversation
        ? []
        : [
            {
                id: `conversation:${conversation.conversationId}`,
                title: text.supportTimelineConversationCreated,
                subtitle: userDisplayName,
                occurredAtUtc: conversation.createdAtUtc,
                tone: "info" as const,
            },
            ...conversation.messages.map((message) => ({
                id: message.messageId,
                title: message.isFromAdmin
                    ? text.supportTimelineAdminReply
                    : text.supportTimelineUserMessage,
                subtitle: `${message.senderDisplayName} • ${truncateText(message.body, 112)}`,
                occurredAtUtc: message.createdAtUtc,
                tone: message.isFromAdmin ? "success" as const : "primary" as const,
            })),
        ].sort((left, right) => new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime());

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
                            {conversation.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{conversation.adminUnreadCount}</span> : null}
                            <Button variant="secondary" size="sm" onClick={() => setIsSidePanelOpen((current) => !current)}>
                                {isSidePanelOpen ? text.supportClosePanelAction : text.supportOpenPanelAction}
                            </Button>
                        </div>
                    </div>

                    <div className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceWithSidebar : styles.workspaceCompact}`}>
                        <AdminCard className={styles.inboxPane}>
                            <div className={styles.paneTopbar}>
                                <div className={styles.paneTitleGroup}>
                                    <span className={styles.paneEyebrow}>{text.supportTitle}</span>
                                    <h2 className={styles.paneTitle}>{text.supportInboxTitle}</h2>
                                    <p className={styles.paneDescription}>{text.supportInboxDescription}</p>
                                </div>
                                <div className={styles.paneCountBadge}>{filteredInboxItems.length}</div>
                            </div>
                            <div className={styles.inboxToolbar}>
                                <SupportOptionGroup
                                    label={text.statusLabel}
                                    value={statusFilter}
                                    options={[
                                        { value: "all", label: text.supportStatusAll },
                                        ...statusOptions.map((status) => ({ value: status, label: statusLabel(status, text) })),
                                    ]}
                                    onChange={(value) => setStatusFilter(value as SupportFilter)}
                                    compact
                                />
                                <label className={styles.searchField}>
                                    <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
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
                                                    <div className={styles.rowTextStack}>
                                                        <div className={styles.rowTitle}>{item.userDisplayName?.trim() || item.userEmail}</div>
                                                        <div className={styles.rowPreview}><span>{item.lastMessagePreview || text.supportNoMessages}</span></div>
                                                    </div>
                                                </div>
                                                <span className={styles.timePill}>{formatRelativeTime(item.lastMessageAtUtc ?? item.updatedAtUtc, locale)}</span>
                                            </div>
                                            <div className={styles.rowSlaLine}>
                                                <span className={`${styles.slaPill} ${styles[`slaPill_${getConversationSla(item.lastMessageAtUtc ?? item.createdAtUtc, locale, item.adminUnreadCount).level}`]}`}>
                                                    {getConversationSla(item.lastMessageAtUtc ?? item.createdAtUtc, locale, item.adminUnreadCount).primaryLabel}
                                                </span>
                                                <div className={styles.rowMetaGroup}>
                                                    {item.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{item.adminUnreadCount}</span> : null}
                                                    {item.status !== "Open" ? <span className={styles.rowSecondaryMeta}>{statusLabel(item.status, text)}</span> : null}
                                                    {item.priority.toLowerCase() === "high" ? <span className={styles.rowSecondaryMeta}>{priorityLabel(item.priority, text)}</span> : null}
                                                </div>
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
                                        <div className={styles.chatFacts}>
                                            {chatFacts.map((fact) => (
                                                <span key={fact} className={styles.chatFactChip}>{fact}</span>
                                            ))}
                                        </div>
                                        <div className={styles.chatMetaLine}>
                                            <span>{conversation.userEmail}</span>
                                            <span>•</span>
                                            <span>{shortId(conversation.initiatorUserId)}</span>
                                            <span>•</span>
                                            <span>{`${text.supportAssignedTo}: ${conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}`}</span>
                                        </div>
                                    </div>

                                    <div className={styles.chatHeaderAside}>
                                        <span className={`${styles.slaPill} ${styles[`slaPill_${conversationSla.level}`]}`}>{conversationSla.waitLabel}</span>
                                        <div className={styles.chatStatusControls}>
                                            <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                            <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                                        </div>
                                        <p className={styles.chatStatusNote}>{statusHint(conversation.status, text)}</p>
                                    </div>
                                </div>

                                {conversation.messages.length > 0 ? (
                                    <div className={styles.messagesWrap}>
                                        <div className={styles.dayDivider}>{text.supportTodayLabel}</div>
                                        <div className={styles.messages}>
                                            {conversation.messages.map((message) => (
                                                <article
                                                    key={message.messageId}
                                                    className={`${styles.messageItem} ${message.isFromAdmin ? styles.messageAdmin : styles.messageUser}`}
                                                >
                                                    <div className={styles.messageHeader}>
                                                        <div className={styles.messageSenderWrap}>
                                                            {!message.isFromAdmin ? <span className={styles.avatarTiny}>{initialsFor(message.senderDisplayName)}</span> : null}
                                                            <strong>{message.senderDisplayName}</strong>
                                                        </div>
                                                        <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                                                    </div>
                                                    {hasImageAttachment(message) ? (
                                                        <a href={message.attachmentUrl!} target="_blank" rel="noreferrer" className={styles.messageImageLink}>
                                                            <Image
                                                                src={message.attachmentUrl!}
                                                                alt={message.attachmentFileName ?? message.body}
                                                                width={704}
                                                                height={576}
                                                                sizes="(max-width: 860px) 100vw, 22rem"
                                                                className={styles.messageImage}
                                                                loading="lazy"
                                                                unoptimized
                                                            />
                                                        </a>
                                                    ) : hasAttachment(message) ? (
                                                        <a href={message.attachmentUrl!} target="_blank" rel="noreferrer" className={styles.messageAttachmentCard}>
                                                            <div className={styles.messageAttachmentIcon}>FILE</div>
                                                            <div className={styles.messageAttachmentMeta}>
                                                                <strong>{message.attachmentFileName ?? message.body}</strong>
                                                                <span>{formatFileSize(message.attachmentFileSizeBytes, locale)}</span>
                                                            </div>
                                                        </a>
                                                    ) : null}
                                                    {shouldRenderMessageBody(message) ? <div className={styles.messageBody}>{message.body}</div> : null}
                                                </article>
                                            ))}
                                        </div>
                                    </div>
                                ) : (
                                    <AdminStateCard tone="info" title={text.supportNoMessages} />
                                )}

                                <div className={styles.composerShell}>
                                    {visibleTemplates.length > 0 ? (
                                        <div className={styles.composerTemplateRail}>
                                            <span className={styles.subtle}>
                                                {text.supportQuickRepliesLabel}
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
                                                        {`✓ ${template.title}`}
                                                    </Button>
                                                ))}
                                            </div>
                                        </div>
                                    ) : null}

                                    <input
                                        ref={attachmentInputRef}
                                        type="file"
                                        className={styles.hiddenFileInput}
                                        accept="image/*,.pdf,.txt,.csv,.json,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip"
                                        onChange={(event) => {
                                            const nextFile = event.target.files?.[0] ?? null;
                                            setSelectedAttachment(nextFile);
                                        }}
                                    />
                                    <div className={styles.composerAttachmentBar}>
                                        <Button
                                            variant="secondary"
                                            size="sm"
                                            onClick={() => attachmentInputRef.current?.click()}
                                            disabled={sendMutation.isPending}
                                        >
                                            {text.chooseFile}
                                        </Button>
                                        <span className={styles.subtle}>{text.supportAttachmentHint}</span>
                                    </div>
                                    {selectedAttachment ? (
                                        <div className={styles.attachmentPreviewCard}>
                                            {attachmentPreviewUrl ? (
                                                <a href={attachmentPreviewUrl} target="_blank" rel="noreferrer" className={styles.attachmentPreviewImageLink}>
                                                    <Image
                                                        src={attachmentPreviewUrl}
                                                        alt={selectedAttachment.name}
                                                        width={72}
                                                        height={72}
                                                        sizes="72px"
                                                        className={styles.attachmentPreviewImage}
                                                        unoptimized
                                                    />
                                                </a>
                                            ) : (
                                                <div className={styles.attachmentPreviewFileIcon}>FILE</div>
                                            )}
                                            <div className={styles.attachmentPreviewMeta}>
                                                <span className={styles.subtle}>{text.selectedFileLabel}</span>
                                                <strong>{selectedAttachment.name}</strong>
                                                <span className={styles.subtle}>{formatFileSize(selectedAttachment.size, locale)}</span>
                                            </div>
                                            <div className={styles.attachmentPreviewActions}>
                                                {attachmentPreviewUrl ? (
                                                    <a href={attachmentPreviewUrl} target="_blank" rel="noreferrer" className={styles.attachmentActionLink}>
                                                        {text.supportAttachmentOpenAction}
                                                    </a>
                                                ) : null}
                                                <Button variant="ghost" size="sm" onClick={resetSelectedAttachment}>
                                                    {text.supportAttachmentRemoveAction}
                                                </Button>
                                            </div>
                                        </div>
                                    ) : null}

                                    <textarea
                                        className={styles.textarea}
                                        value={composerValue}
                                        onChange={(event) => setReply(event.target.value)}
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
                                                onClick={() => sendMutation.mutate()}
                                                disabled={sendMutation.isPending || (!reply.trim() && !hasComposerAttachment)}
                                            >
                                                {sendMutation.isPending ? text.supportReplySending : text.supportReplyAction}
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            </AdminCard>
                        </div>

                        {isSidePanelOpen ? <div className={styles.sidePane}>
                            <AdminCard className={`${styles.sideCard} ${styles.sidePanelCard}`}>
                                <div className={styles.sidePanelTopbar}>
                                    <div className={styles.paneTitleGroup}>
                                        <span className={styles.paneEyebrow}>{text.supportConversationDetailsTitle}</span>
                                        <h2 className={styles.paneTitle}>{sidePanelTitle}</h2>
                                        {sidePanelDescription ? <p className={styles.paneDescription}>{sidePanelDescription}</p> : null}
                                    </div>
                                    <div className={styles.sidePanelTabs}>
                                        {sidePanelTabs.map(({ value, label }) => (
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
                                </div>
                                {activeSidePanelTab === "profile" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.statusOverviewCard}>
                                            <div className={styles.statusOverviewHeader}>
                                                <div className={styles.statusOverviewCopy}>
                                                    <span className={styles.paneEyebrow}>{text.supportStatusWorkflowTitle}</span>
                                                    <strong className={styles.statusOverviewTitle}>{statusLabel(conversation.status, text)}</strong>
                                                    <p className={styles.statusOverviewText}>{statusHint(conversation.status, text)}</p>
                                                </div>
                                                <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                            </div>
                                            <div className={styles.workflowPrimaryRow}>
                                                <Button
                                                    variant="secondary"
                                                    className={styles.workflowSecondaryButton}
                                                    onClick={() => assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)}
                                                    disabled={assignmentMutation.isPending || !sessionUserId}
                                                >
                                                    {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                                                </Button>
                                                {primaryStatusAction ? (
                                                    <Button
                                                        variant="primary"
                                                        className={styles.workflowPrimaryButton}
                                                        onClick={() => statusMutation.mutate(primaryStatusAction.status)}
                                                        disabled={statusMutation.isPending || conversation.status === primaryStatusAction.status}
                                                    >
                                                        {primaryStatusAction.label}
                                                    </Button>
                                                ) : null}
                                            </div>
                                            {secondaryStatusActions.length ? (
                                                <div className={styles.workflowSecondaryGrid}>
                                                    {secondaryStatusActions.map((action) => (
                                                        <Button
                                                            key={action.status}
                                                            variant="secondary"
                                                            className={styles.workflowSecondaryButton}
                                                            onClick={() => statusMutation.mutate(action.status)}
                                                            disabled={statusMutation.isPending || conversation.status === action.status}
                                                        >
                                                            {action.label}
                                                        </Button>
                                                    ))}
                                                </div>
                                            ) : null}
                                            {destructiveStatusAction ? (
                                                <div className={styles.workflowDangerZone}>
                                                    <span className={styles.workflowDangerLabel}>{text.supportCloseConversationAction}</span>
                                                    <Button
                                                        variant="danger"
                                                        className={styles.workflowDangerButton}
                                                        onClick={() => statusMutation.mutate(destructiveStatusAction.status)}
                                                        disabled={statusMutation.isPending || conversation.status === destructiveStatusAction.status}
                                                    >
                                                        {destructiveStatusAction.label}
                                                    </Button>
                                                </div>
                                            ) : null}
                                            <p className={styles.statusOverviewHint}>{text.supportStatusAutomationHint}</p>
                                        </div>

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
                                            <div className={styles.metricTile}><span>{text.supportAccountAgeLabel}</span><strong>{formatAccountAge(accountCreatedAt, locale)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportMessagesCount}</span><strong>{String(conversation.messages.length)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportPurchasesLabel}</span><strong>{String(totalPurchases)}</strong></div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportConversationMetaTitle}</strong>
                                            </div>
                                            <div className={styles.detailGrid}>
                                                <div className={styles.detailRow}><span>{text.statusLabel}</span><strong>{statusLabel(conversation.status, text)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportAssignedTo}</span><strong>{conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</strong></div>
                                                <div className={styles.detailRow}><span>{text.createdAtLabel}</span><strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportLastMessage}</span><strong>{formatDateTime(conversation.lastMessageAtUtc ?? conversation.createdAtUtc, locale)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportLastSeenLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastActivityAtUtc, locale)}</strong></div>
                                            </div>
                                        </div>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "purchases" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportPurchasesLabel}</span><strong>{String(totalPurchases)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastPaymentLabel}</span><strong>{analyticsQuery.data?.summary.lastPurchaseAtUtc ? formatRelativeTime(analyticsQuery.data.summary.lastPurchaseAtUtc, locale) : "—"}</strong></div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportRecentPurchasesTitle}</strong>
                                            </div>
                                            {analyticsQuery.isLoading ? (
                                                <AdminStateCard tone="info" title={text.loading} />
                                            ) : analyticsQuery.isError ? (
                                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                                            ) : analyticsQuery.data?.recentPurchases.length ? (
                                                <div className={styles.timelineList}>
                                                    {analyticsQuery.data.recentPurchases.slice(0, 4).map((purchase) => (
                                                        <article key={purchase.orderId} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{formatMoney(purchase.priceAmount, purchase.currencyCode, locale)}</strong>
                                                                <span>{formatRelativeTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}</span>
                                                            </div>
                                                            <div className={styles.rowMetaGroup}>
                                                                <AdminBadge tone={purchase.status.toLowerCase() === "paid" || purchase.status.toLowerCase() === "completed" ? "success" : "warning"}>{purchase.status}</AdminBadge>
                                                                <span className={styles.subtle}>{`${purchase.sparkToGrant} spark`}</span>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{purchase.paymentProvider}</p>
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.supportNoPurchases} />
                                            )}
                                        </div>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "generations" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.completedGenerationsLabel}</span><strong>{analyticsQuery.data ? String(analyticsQuery.data.summary.completedGenerations) : "—"}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastGenerationLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}</strong></div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportRecentGenerationsTitle}</strong>
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

                                {activeSidePanelTab === "errors" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportGenerationErrorsTitle}</span><strong>{String(analyticsQuery.data?.summary.failedGenerations ?? failedGenerations.length)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastSeenLabel}</span><strong>{recentFailures[0]?.lastOccurredAtUtc ? formatRelativeTime(recentFailures[0].lastOccurredAtUtc, locale) : "—"}</strong></div>
                                        </div>

                                        <div className={styles.sectionBlock}>
                                            <div className={styles.sectionHeaderCompact}>
                                                <strong>{text.supportGenerationErrorsTitle}</strong>
                                            </div>
                                            {analyticsQuery.isLoading ? (
                                                <AdminStateCard tone="info" title={text.loading} />
                                            ) : analyticsQuery.isError ? (
                                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                                            ) : recentFailures.length ? (
                                                <div className={styles.timelineList}>
                                                    {recentFailures.map((item) => (
                                                        <article key={item.failureCode} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{item.failureCode}</strong>
                                                                <span>{formatRelativeTime(item.lastOccurredAtUtc, locale)}</span>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{`${text.supportOccurrencesLabel}: ${item.count}`}</p>
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : failedGenerations.length ? (
                                                <div className={styles.timelineList}>
                                                    {failedGenerations.slice(0, 3).map((generation) => (
                                                        <article key={generation.generationId} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{generation.templateTitle}</strong>
                                                                <span>{formatRelativeTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}</span>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{generation.failureMessage ?? generation.failureCode ?? generation.status}</p>
                                                        </article>
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.supportNoGenerationErrors} />
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
                                                                    <AdminBadge tone="primary">{text.supportTemplateKindReply}</AdminBadge>
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
                                            ) : activityTimeline.length ? (
                                                <div className={styles.timelineList}>
                                                    {activityTimeline.map((item) => (
                                                        <article key={item.id} className={styles.timelineCard}>
                                                            <div className={styles.timelineCardHeader}>
                                                                <strong>{item.title}</strong>
                                                                <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                                                            </div>
                                                            <p className={styles.timelineCardBody}>{item.subtitle}</p>
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

function statusHint(status: SupportConversationStatus, text: ReturnType<typeof getDictionary>) {
    switch (status) {
        case "Open":
            return text.supportStatusOpenHint;
        case "InProgress":
            return text.supportStatusInProgressHint;
        case "Resolved":
            return text.supportStatusResolvedHint;
        case "Closed":
            return text.supportStatusClosedHint;
        default:
            return text.supportConversationDescription;
    }
}

function getAvailableStatusActions(status: SupportConversationStatus, text: ReturnType<typeof getDictionary>): StatusActionDescriptor[] {
    switch (status) {
        case "Open":
            return [
                { status: "InProgress", label: text.supportMarkInProgressAction, variant: "primary" },
                { status: "Resolved", label: text.supportResolveConversationAction, variant: "secondary" },
                { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
            ];
        case "InProgress":
            return [
                { status: "Resolved", label: text.supportResolveConversationAction, variant: "primary" },
                { status: "Open", label: text.supportReopenConversationAction, variant: "secondary" },
                { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
            ];
        case "Resolved":
            return [
                { status: "Open", label: text.supportReopenConversationAction, variant: "secondary" },
                { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
            ];
        case "Closed":
            return [
                { status: "Open", label: text.supportReopenConversationAction, variant: "primary" },
            ];
        default:
            return [];
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

function getConversationSla(value: string | null | undefined, locale: Locale, unreadCount = 0) {
    const diffMinutes = Math.max(0, Math.round((Date.now() - new Date(value ?? Date.now()).getTime()) / 60000));

    let level: "good" | "warning" | "risk" | "critical" = "critical";
    if (diffMinutes < 30) {
        level = "good";
    } else if (diffMinutes < 180) {
        level = "warning";
    } else if (diffMinutes < 720) {
        level = "risk";
    }

    const waitLabel = locale === "ru"
        ? `${getWaitPrefix(locale)} ${formatWaitTime(value, locale)}`
        : `${getWaitPrefix(locale)} ${formatWaitTime(value, locale)}`;

    return {
        level,
        waitLabel,
        primaryLabel: unreadCount > 0
            ? (locale === "ru" ? "Новый ответ пользователя" : "New user reply")
            : waitLabel,
    };
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

function getWaitPrefix(locale: Locale) {
    return locale === "ru" ? "Ожидает" : "Waiting";
}

function formatAccountAge(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return locale === "ru" ? "новый" : "new";
    }

    const diffDays = Math.max(1, Math.floor((Date.now() - new Date(value).getTime()) / 86400000));
    if (diffDays < 30) {
        return locale === "ru" ? `${diffDays} дн` : `${diffDays}d`;
    }

    if (diffDays < 365) {
        const diffMonths = Math.max(1, Math.floor(diffDays / 30));
        return locale === "ru" ? `${diffMonths} мес` : `${diffMonths} mo`;
    }

    const diffYears = Math.max(1, Math.floor(diffDays / 365));
    return locale === "ru" ? `${diffYears} г` : `${diffYears} yr`;
}

function formatAccountAgeFact(value: string | null | undefined, locale: Locale) {
    return locale === "ru" ? `Аккаунт ${formatAccountAge(value, locale)}` : `Account ${formatAccountAge(value, locale)}`;
}

function formatCountFact(value: number, locale: Locale, kind: "messages" | "purchases") {
    if (locale === "ru") {
        if (kind === "messages") {
            return `${value} ${pluralizeRu(value, "сообщение", "сообщения", "сообщений")}`;
        }

        return `${value} ${pluralizeRu(value, "покупка", "покупки", "покупок")}`;
    }

    if (kind === "messages") {
        return `${value} ${value === 1 ? "message" : "messages"}`;
    }

    return `${value} ${value === 1 ? "purchase" : "purchases"}`;
}

function pluralizeRu(value: number, one: string, few: string, many: string) {
    const abs = Math.abs(value) % 100;
    const last = abs % 10;

    if (abs > 10 && abs < 20) {
        return many;
    }

    if (last === 1) {
        return one;
    }

    if (last >= 2 && last <= 4) {
        return few;
    }

    return many;
}

function formatMoney(amount: number, currencyCode: string, locale: Locale) {
    return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
        style: "currency",
        currency: currencyCode,
        maximumFractionDigits: 2,
    }).format(amount);
}

function hasAttachment(message: Pick<AdminSupportConversation["messages"][number], "attachmentUrl">) {
    return Boolean(message.attachmentUrl?.trim());
}

function hasImageAttachment(message: Pick<AdminSupportConversation["messages"][number], "attachmentUrl" | "attachmentContentType">) {
    return hasAttachment(message) && Boolean(message.attachmentContentType?.startsWith("image/"));
}

function shouldRenderMessageBody(message: Pick<AdminSupportConversation["messages"][number], "body" | "attachmentFileName" | "attachmentUrl">) {
    const normalizedBody = message.body.trim();
    if (!normalizedBody) {
        return false;
    }

    if (!hasAttachment(message)) {
        return true;
    }

    return normalizedBody !== (message.attachmentFileName?.trim() ?? "");
}

function formatFileSize(value: number | null | undefined, locale: Locale) {
    if (!value || value <= 0) {
        return locale === "ru" ? "Размер не указан" : "Size unavailable";
    }

    if (value < 1024) {
        return `${value} B`;
    }

    const kilobytes = value / 1024;
    if (kilobytes < 1024) {
        return locale === "ru" ? `${kilobytes.toFixed(1)} КБ` : `${kilobytes.toFixed(1)} KB`;
    }

    const megabytes = kilobytes / 1024;
    return locale === "ru" ? `${megabytes.toFixed(1)} МБ` : `${megabytes.toFixed(1)} MB`;
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
