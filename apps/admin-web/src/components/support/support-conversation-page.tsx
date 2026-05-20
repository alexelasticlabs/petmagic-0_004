"use client";

import { AdminBadge, AdminCard, AdminMetricStrip, AdminPage, AdminPageHero, AdminSelectField, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    assignSupportConversation,
    createSupportReplyTemplate,
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
    const [reply, setReply] = useState("");
    const [internalNote, setInternalNote] = useState("");
    const [statusDraft, setStatusDraft] = useState<SupportConversationStatus | null>(null);
    const [templateDraft, setTemplateDraft] = useState<TemplateDraft>(emptyTemplateDraft);
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
            setStatusDraft(null);
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
        onSuccess: async () => {
            setTemplateDraft(emptyTemplateDraft);
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
            setToast({ type: "success", message: text.supportTemplateDeleted });
            await refreshTemplateCatalog();
        },
        onError: () => {
            setToast({ type: "error", message: text.supportLoadError });
        },
    });

    const conversation = conversationQuery.data;
    const selectedStatus = statusDraft ?? conversation?.status ?? "Open";
    const sessionUserId = session?.user.userId ?? null;
    const isAssignedToCurrentAdmin = Boolean(sessionUserId && conversation?.assignedAdminId === sessionUserId);
    const replyTemplates = useMemo(
        () => (templatesQuery.data ?? []).filter((template) => template.isEnabled && template.kind === "Reply").sort((left, right) => left.sortOrder - right.sortOrder),
        [templatesQuery.data],
    );
    const internalNoteTemplates = useMemo(
        () => (templatesQuery.data ?? []).filter((template) => template.isEnabled && template.kind === "InternalNote").sort((left, right) => left.sortOrder - right.sortOrder),
        [templatesQuery.data],
    );
    const metaItems = useMemo(() => {
        if (!conversation) {
            return [];
        }

        return [
            `${text.supportUserLabel}: ${conversation.userDisplayName?.trim() || conversation.userEmail}`,
            `${text.supportAssignedTo}: ${conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}`,
            `${text.supportUnreadUser}: ${conversation.userUnreadCount}`,
            `${text.supportUnreadAdmin}: ${conversation.adminUnreadCount}`,
        ];
    }, [conversation, text.supportAssignedTo, text.supportUnassigned, text.supportUnreadAdmin, text.supportUnreadUser, text.supportUserLabel]);

    return (
        <AdminPage className={styles.page}>
            <AdminPageHero
                eyebrow={text.supportTitle}
                title={conversation?.userDisplayName?.trim() || conversation?.userEmail || text.supportConversationTitle}
                description={text.supportConversationDescription}
                actions={<Link href={`/${locale}/support`} className="ui-button ui-button--secondary ui-button--md">{text.supportBackToInbox}</Link>}
                metaItems={metaItems}
            />

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
                <div className={styles.detail}>
                    <AdminCard title={text.supportConversationTitle} description={text.supportDescription}>
                        <div className={styles.detailHeader}>
                            <div className={styles.rowMeta}>
                                <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                <AdminBadge tone="neutral">{conversation.priority}</AdminBadge>
                            </div>
                            <div className={styles.rowMeta}>
                                <div className={styles.statusSelect}>
                                    <AdminSelectField
                                        label={text.statusLabel}
                                        value={selectedStatus}
                                        options={statusOptions.map((status) => ({ value: status, label: statusLabel(status, text) }))}
                                        onChange={(value) => setStatusDraft(value as SupportConversationStatus)}
                                    />
                                </div>
                                <Button
                                    variant="secondary"
                                    onClick={() => assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)}
                                    disabled={assignmentMutation.isPending || !sessionUserId}
                                >
                                    {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                                </Button>
                            </div>
                        </div>

                        <div className={styles.detailMeta}>
                            <div className={styles.detailMetric}>
                                <span>{text.supportUserLabel}</span>
                                <strong>{conversation.userDisplayName?.trim() || conversation.userEmail}</strong>
                            </div>
                            <div className={styles.detailMetric}>
                                <span>{text.supportAssignedTo}</span>
                                <strong>{conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</strong>
                            </div>
                            <div className={styles.detailMetric}>
                                <span>{text.supportLastMessage}</span>
                                <strong>{formatDateTime(conversation.lastMessageAtUtc ?? conversation.updatedAtUtc, locale)}</strong>
                            </div>
                        </div>
                    </AdminCard>

                    <AdminCard title={text.supportConversationTitle}>
                        {conversation.messages.length > 0 ? (
                            <div className={styles.messages}>
                                {conversation.messages.map((message) => (
                                    <article
                                        key={message.messageId}
                                        className={`${styles.messageItem} ${message.isInternalNote ? styles.messageNote : message.isFromAdmin ? styles.messageAdmin : styles.messageUser}`}
                                    >
                                        <div className={styles.messageHeader}>
                                            <strong>{message.senderDisplayName}</strong>
                                            {message.isInternalNote ? <AdminBadge tone="warning">{text.supportInternalNoteBadge}</AdminBadge> : null}
                                            <span>{formatDateTime(message.createdAtUtc, locale)}</span>
                                        </div>
                                        <div className={styles.messageBody}>{message.body}</div>
                                    </article>
                                ))}
                            </div>
                        ) : (
                            <AdminStateCard tone="info" title={text.supportNoMessages} />
                        )}
                    </AdminCard>

                    <AdminCard title={text.supportReplyAction}>
                        <div className={styles.composerStack}>
                            <div className={styles.composer}>
                                <div className={styles.templateSection}>
                                    <span className={styles.subtle}>{text.supportQuickRepliesLabel}</span>
                                    <div className={styles.templateList}>
                                        {replyTemplates.map((template) => (
                                            <Button key={template.templateId} size="sm" variant="ghost" onClick={() => setReply(mergeTemplateDraft(reply, template.body))}>
                                                {template.title}
                                            </Button>
                                        ))}
                                    </div>
                                </div>
                                <textarea
                                    className={styles.textarea}
                                    value={reply}
                                    onChange={(event) => setReply(event.target.value)}
                                    placeholder={text.supportReplyPlaceholder}
                                />
                                <div className={styles.composerActions}>
                                    <AdminMetricStrip
                                        items={[
                                            { label: text.supportUnreadAdmin, value: String(conversation.adminUnreadCount) },
                                            { label: text.supportUnreadUser, value: String(conversation.userUnreadCount) },
                                        ]}
                                    />
                                    <div className={styles.rowMeta}>
                                        <Button variant="secondary" onClick={() => statusMutation.mutate(selectedStatus)} disabled={statusMutation.isPending}>
                                            {statusMutation.isPending ? text.loading : text.supportSaveStatusAction}
                                        </Button>
                                        <Button variant="primary" onClick={() => sendMutation.mutate()} disabled={sendMutation.isPending || !reply.trim()}>
                                            {sendMutation.isPending ? text.supportReplySending : text.supportReplyAction}
                                        </Button>
                                    </div>
                                </div>
                            </div>

                            <div className={styles.composer}>
                                <div className={styles.templateSection}>
                                    <span className={styles.subtle}>{text.supportInternalNoteTemplatesLabel}</span>
                                    <div className={styles.templateList}>
                                        {internalNoteTemplates.map((template) => (
                                            <Button key={template.templateId} size="sm" variant="ghost" onClick={() => setInternalNote(mergeTemplateDraft(internalNote, template.body))}>
                                                {template.title}
                                            </Button>
                                        ))}
                                    </div>
                                </div>
                                <textarea
                                    className={styles.textarea}
                                    value={internalNote}
                                    onChange={(event) => setInternalNote(event.target.value)}
                                    placeholder={text.supportInternalNotePlaceholder}
                                />
                                <div className={styles.composerActions}>
                                    <span className={styles.subtle}>{text.supportInternalNoteBadge}</span>
                                    <Button variant="secondary" onClick={() => noteMutation.mutate()} disabled={noteMutation.isPending || !internalNote.trim()}>
                                        {noteMutation.isPending ? text.loading : text.supportInternalNoteAction}
                                    </Button>
                                </div>
                            </div>
                        </div>
                    </AdminCard>

                    <AdminCard title={text.supportTemplatesManagerTitle} description={text.supportTemplatesManagerDescription}>
                        <div className={styles.templateManager}>
                            {templatesQuery.isLoading ? (
                                <AdminStateCard tone="info" title={text.loading} />
                            ) : templatesQuery.isError ? (
                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                            ) : (templatesQuery.data?.length ?? 0) === 0 ? (
                                <AdminStateCard tone="info" title={text.supportTemplateNoTemplates} />
                            ) : (
                                (templatesQuery.data ?? []).slice().sort((left, right) => left.sortOrder - right.sortOrder).map((template) => (
                                    <article key={template.templateId} className={styles.templateRow}>
                                        <div className={styles.templateRowHeader}>
                                            <div>
                                                <div className={styles.rowTitle}>{template.title}</div>
                                                <div className={styles.rowMeta}>
                                                    <AdminBadge tone={template.kind === "Reply" ? "primary" : "warning"}>
                                                        {template.kind === "Reply" ? text.supportTemplateKindReply : text.supportTemplateKindInternalNote}
                                                    </AdminBadge>
                                                    {!template.isEnabled ? <AdminBadge tone="neutral">{text.supportTemplateDisabledBadge}</AdminBadge> : null}
                                                </div>
                                            </div>
                                            <div className={styles.templateRowActions}>
                                                <Button
                                                    size="sm"
                                                    variant="secondary"
                                                    onClick={() => setTemplateDraft({
                                                        templateId: template.templateId,
                                                        title: template.title,
                                                        body: template.body,
                                                        kind: template.kind,
                                                        isEnabled: template.isEnabled,
                                                        sortOrder: template.sortOrder,
                                                    })}
                                                >
                                                    {text.supportTemplateEditAction}
                                                </Button>
                                                <Button size="sm" variant="danger" onClick={() => templateDeleteMutation.mutate(template.templateId)} disabled={templateDeleteMutation.isPending}>
                                                    {text.supportTemplateDeleteAction}
                                                </Button>
                                            </div>
                                        </div>
                                        <div className={styles.messageBody}>{template.body}</div>
                                    </article>
                                ))
                            )}

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
                                </div>
                            </div>
                        </div>
                    </AdminCard>
                </div>
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

function formatDateTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
        dateStyle: "medium",
        timeStyle: "short",
    }).format(new Date(value));
}

function mergeTemplateDraft(currentValue: string, template: string) {
    const normalizedCurrentValue = currentValue.trim();
    if (!normalizedCurrentValue) {
        return template;
    }

    return `${normalizedCurrentValue}\n\n${template}`;
}