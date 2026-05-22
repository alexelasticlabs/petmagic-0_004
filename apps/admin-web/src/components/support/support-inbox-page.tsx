"use client";

import Link from "next/link";
import { useMemo } from "react";

import { AdminBadge, AdminCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { formatRelativeTime, formatWaitTime, initialsFor } from "@/components/support/support-conversation-helpers";
import { SupportOptionGroup } from "@/components/support/support-option-group";
import styles from "@/components/support/support-page.module.css";
import { priorityLabel, priorityTone, statusLabel, toneForStatus } from "@/components/support/support-status-helpers";
import {
    type AssignmentFilter,
    type SupportFilter,
    useSupportInboxController,
} from "@/components/support/use-support-inbox-controller";
import { Button } from "@/components/ui/button";
import { type Locale } from "@/lib/i18n";

type SupportInboxPageProps = {
    locale: Locale;
};

export function SupportInboxPage({ locale }: SupportInboxPageProps) {
    const { assignment, filteredConversations, inboxQuery, searchQuery, setAssignment, setSearchQuery, setStatus, status, text } = useSupportInboxController({ locale });

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
                                        <span className={styles.timePill}>{formatRelativeTime(conversation.lastMessageAtUtc ?? conversation.updatedAtUtc, locale, "verbose")}</span>
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
