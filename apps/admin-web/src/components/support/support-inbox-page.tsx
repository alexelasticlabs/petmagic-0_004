"use client";

import { AdminBadge, AdminCard, AdminPage, AdminPageHero, AdminSelectField, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchSupportInbox, useAuthSession, type AdminSupportConversationSummary, type SupportConversationStatus, type SupportInboxAssignmentScope } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useSupportRealtime } from "@/lib/support-realtime";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import styles from "@/components/support/support-page.module.css";

type SupportInboxPageProps = {
    locale: Locale;
};

type SupportFilter = "all" | SupportConversationStatus;
type AssignmentFilter = SupportInboxAssignmentScope;

export function SupportInboxPage({ locale }: SupportInboxPageProps) {
    const text = getDictionary(locale);
    const router = useRouter();
    const session = useAuthSession();
    const queryClient = useQueryClient();
    const [status, setStatus] = useState<SupportFilter>("all");
    const [assignment, setAssignment] = useState<AssignmentFilter>("all");

    useEffect(() => {
        if (!session) {
            ensureAdminSession(locale, router);
        }
    }, [locale, router, session]);

    const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
        queryKey: adminQueryKeys.supportInbox(status, assignment),
        queryFn: () => fetchSupportInbox(status === "all" ? undefined : status, assignment),
        enabled: Boolean(session),
    });

    useSupportRealtime(session?.accessToken, () => {
        void queryClient.invalidateQueries({ queryKey: ["admin", "support", "inbox"] });
    });

    const statusOptions = useMemo(
        () => [
            { value: "all", label: text.supportStatusAll },
            { value: "Open", label: text.supportStatusOpen },
            { value: "InProgress", label: text.supportStatusInProgress },
            { value: "Resolved", label: text.supportStatusResolved },
            { value: "Closed", label: text.supportStatusClosed },
        ],
        [text.supportStatusAll, text.supportStatusClosed, text.supportStatusInProgress, text.supportStatusOpen, text.supportStatusResolved],
    );

    const assignmentOptions = useMemo(
        () => [
            { value: "all", label: text.supportAssignmentAll },
            { value: "mine", label: text.supportAssignmentMine },
            { value: "unassigned", label: text.supportAssignmentUnassigned },
        ],
        [text.supportAssignmentAll, text.supportAssignmentMine, text.supportAssignmentUnassigned],
    );

    return (
        <AdminPage className={styles.page}>
            <AdminPageHero
                eyebrow={text.supportTitle}
                title={text.supportInboxTitle}
                description={text.supportInboxDescription}
                metaItems={[
                    `${text.statusLabel}: ${statusOptions.find((option) => option.value === status)?.label ?? text.supportStatusAll}`,
                    `${text.supportAssignedTo}: ${assignmentOptions.find((option) => option.value === assignment)?.label ?? text.supportAssignmentAll}`,
                    `${text.supportInboxTitle}: ${String(inboxQuery.data?.length ?? 0)}`,
                ]}
            />

            <AdminCard
                title={text.supportInboxTitle}
                description={text.supportDescription}
                action={
                    <div className={styles.toolbar}>
                        <div className={styles.statusSelect}>
                            <AdminSelectField
                                label={text.statusLabel}
                                value={status}
                                options={statusOptions}
                                onChange={(value) => setStatus(value as SupportFilter)}
                            />
                        </div>
                        <div className={styles.statusSelect}>
                            <AdminSelectField
                                label={text.supportAssignedTo}
                                value={assignment}
                                options={assignmentOptions}
                                onChange={(value) => setAssignment(value as AssignmentFilter)}
                            />
                        </div>
                        <Button variant="secondary" onClick={() => void inboxQuery.refetch()}>{text.supportRefresh}</Button>
                    </div>
                }
            >
                {inboxQuery.isLoading ? (
                    <AdminStateCard tone="info" title={text.loading} description={text.supportInboxDescription} />
                ) : inboxQuery.isError ? (
                    <AdminStateCard tone="danger" title={text.supportLoadError} description={text.supportDescription} />
                ) : (inboxQuery.data?.length ?? 0) === 0 ? (
                    <AdminStateCard tone="info" title={text.supportEmpty} />
                ) : (
                    <div className={styles.list}>
                        {(inboxQuery.data ?? []).map((conversation) => (
                            <Link key={conversation.conversationId} href={`/${locale}/support/${conversation.conversationId}`} className={styles.conversationRow}>
                                <div className={styles.rowHeader}>
                                    <div>
                                        <div className={styles.rowTitle}>{conversation.userDisplayName?.trim() || conversation.userEmail}</div>
                                        <div className={styles.subtle}>{conversation.userEmail}</div>
                                    </div>
                                    <div className={styles.rowMeta}>
                                        <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                        {conversation.adminUnreadCount > 0 ? (
                                            <AdminBadge tone="warning">{`${text.supportUnreadAdmin}: ${conversation.adminUnreadCount}`}</AdminBadge>
                                        ) : null}
                                    </div>
                                </div>
                                <div className={styles.rowPreview}>
                                    {conversation.lastMessageIsInternalNote ? <AdminBadge tone="warning">{text.supportInternalNoteBadge}</AdminBadge> : null}
                                    {conversation.lastMessagePreview || text.supportNoMessages}
                                </div>
                                <div className={styles.rowFooter}>
                                    <div className={styles.rowMetaGroup}>
                                        <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                                        <span>{text.supportAssignedTo}: {conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</span>
                                    </div>
                                    <div className={styles.rowMetaGroup}>
                                        {conversation.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{conversation.adminUnreadCount}</span> : null}
                                        <span className={styles.waitingLabel}>{`${text.supportWaitingLabel}: ${formatWaitTime(conversation.lastMessageAtUtc ?? conversation.createdAtUtc, locale)}`}</span>
                                    </div>
                                </div>
                            </Link>
                        ))}
                    </div>
                )}
            </AdminCard>
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