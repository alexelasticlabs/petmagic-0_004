"use client";

import { AdminBadge, AdminCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { SupportOptionGroup } from "@/components/support/support-option-group";
import styles from "@/components/support/support-page.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchSupportInbox, useAuthSession, type AdminSupportConversationSummary, type SupportConversationStatus, type SupportInboxAssignmentScope } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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
    const [searchQuery, setSearchQuery] = useState("");

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

    const filteredConversations = useMemo(() => {
        const normalizedQuery = searchQuery.trim().toLowerCase();
        const conversations = inboxQuery.data ?? [];
        if (!normalizedQuery) {
            return conversations;
        }

        return conversations.filter((conversation) => {
            const searchableText = [
                conversation.userDisplayName,
                conversation.userEmail,
                conversation.lastMessagePreview,
                conversation.assignedAdminDisplayName,
            ]
                .filter(Boolean)
                .join(" ")
                .toLowerCase();

            return searchableText.includes(normalizedQuery);
        });
    }, [inboxQuery.data, searchQuery]);
    return (
        <AdminPage className={styles.page}>
            <AdminCard title={text.supportInboxTitle} description={text.supportInboxDescription} className={styles.inboxShellCompact}>
                <div className={styles.inboxControlClusterCompact}>
                    <label className={styles.searchField}>
                        <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
                        <input
                            className={styles.searchInput}
                            value={searchQuery}
                            onChange={(event) => setSearchQuery(event.target.value)}
                            placeholder={text.supportSearchPlaceholder}
                        />
                    </label>
                    <div className={styles.supportControlStack}>
                        <SupportOptionGroup
                            label={text.statusLabel}
                            value={status}
                            options={statusOptions}
                            onChange={(value) => setStatus(value as SupportFilter)}
                        />
                        <SupportOptionGroup
                            label={text.supportAssignedTo}
                            value={assignment}
                            options={assignmentOptions}
                            onChange={(value) => setAssignment(value as AssignmentFilter)}
                        />
                    </div>
                    <div className={styles.toolbarCompactEnd}>
                        <Button variant="secondary" size="sm" onClick={() => void inboxQuery.refetch()}>{text.supportRefresh}</Button>
                    </div>
                </div>
                {inboxQuery.isLoading ? (
                    <AdminStateCard tone="info" title={text.loading} description={text.supportInboxDescription} />
                ) : inboxQuery.isError ? (
                    <AdminStateCard tone="danger" title={text.supportLoadError} description={text.supportDescription} />
                ) : (inboxQuery.data?.length ?? 0) === 0 ? (
                    <AdminStateCard tone="info" title={text.supportEmpty} />
                ) : filteredConversations.length === 0 ? (
                    <AdminStateCard tone="info" title={text.supportEmpty} description={text.supportSearchPlaceholder} />
                ) : (
                    <div className={styles.inboxQueueGrid}>
                        {filteredConversations.map((conversation) => (
                            <Link key={conversation.conversationId} href={`/${locale}/support/${conversation.conversationId}`} className={styles.conversationRow}>
                                <div className={styles.rowHeader}>
                                    <div className={styles.rowIdentity}>
                                        <span className={styles.avatar}>{initialsFor(conversation.userDisplayName?.trim() || conversation.userEmail)}</span>
                                        <div className={styles.rowTextStack}>
                                            <div className={styles.rowTitle}>{conversation.userDisplayName?.trim() || conversation.userEmail}</div>
                                            <div className={styles.subtle}>{conversation.userEmail}</div>
                                        </div>
                                    </div>
                                    <div className={styles.rowMeta}>
                                        <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                        <span className={styles.timePill}>{formatRelativeTime(conversation.lastMessageAtUtc ?? conversation.updatedAtUtc, locale)}</span>
                                    </div>
                                </div>
                                <div className={styles.rowPreview}>
                                    <span>{conversation.lastMessagePreview || text.supportNoMessages}</span>
                                </div>
                                <div className={styles.rowFooter}>
                                    <div className={styles.rowMetaGroup}>
                                        <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                                        {conversation.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{conversation.adminUnreadCount}</span> : null}
                                        <span className={styles.rowDetailValue}>{conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</span>
                                    </div>
                                    <div className={styles.rowMetaGroup}>
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

function initialsFor(value: string) {
    return value
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? "")
        .join("") || "PM";
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

function formatRelativeTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    const diffMinutes = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 60000));
    if (diffMinutes < 60) {
        return locale === "ru" ? `${diffMinutes} мин назад` : `${diffMinutes} min ago`;
    }

    const diffHours = Math.round(diffMinutes / 60);
    if (diffHours < 24) {
        return locale === "ru" ? `${diffHours} ч назад` : `${diffHours}h ago`;
    }

    const diffDays = Math.round(diffHours / 24);
    return locale === "ru" ? `${diffDays} дн назад` : `${diffDays}d ago`;
}
