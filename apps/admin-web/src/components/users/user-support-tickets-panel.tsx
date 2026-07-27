"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { AdminBadge, AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import {
  priorityLabel,
  priorityTone,
  statusLabel,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { Button } from "@/components/ui/button";
import type { UserDetailWorkspaceText } from "@/components/users/user-detail-page.content";
import styles from "@/components/users/user-detail-page.module.css";
import { getUserSupportTicketsPlaceholderData } from "@/components/users/user-support-tickets-panel.helpers";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { fetchAdminUserSupportTickets } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const SUPPORT_PAGE_SIZE = 20;

type UserSupportTicketsPanelProps = {
  locale: Locale;
  retryLabel: string;
  text: UserDetailWorkspaceText;
  userId: string;
};

export function UserSupportTicketsPanel({
  locale,
  retryLabel,
  text,
  userId,
}: UserSupportTicketsPanelProps) {
  const dictionary = getDictionary(locale);
  const [pageState, setPageState] = useState({ page: 1, userId });
  const page = pageState.userId === userId ? pageState.page : 1;
  const ticketsQuery = useQuery({
    queryKey: ["admin", "users", userId, "support", "tickets", page, SUPPORT_PAGE_SIZE],
    queryFn: ({ signal }) =>
      fetchAdminUserSupportTickets(userId, { page, pageSize: SUPPORT_PAGE_SIZE, signal }),
    placeholderData: (previousData, previousQuery) =>
      getUserSupportTicketsPlaceholderData(previousData, previousQuery?.queryKey, userId),
  });

  function updatePage(nextPage: (currentPage: number) => number) {
    setPageState((current) => {
      const currentPage = current.userId === userId ? current.page : 1;
      const resolvedPage = nextPage(currentPage);

      return current.userId === userId && resolvedPage === currentPage
        ? current
        : { page: resolvedPage, userId };
    });
  }

  const tickets = ticketsQuery.data?.items ?? [];
  const totalCount = ticketsQuery.data?.totalCount ?? 0;
  const currentPage = ticketsQuery.data?.page ?? page;
  const pageSize = ticketsQuery.data?.pageSize ?? SUPPORT_PAGE_SIZE;
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
  const hasTickets = tickets.length > 0;
  const isInitialLoading = ticketsQuery.isLoading && !hasTickets;
  const hasRecoverablePagination = totalCount > 0 && (totalPages > 1 || currentPage > 1);

  return (
    <AdminCard
      title={totalCount ? `${text.supportTitle} · ${totalCount}` : text.supportTitle}
      description={text.supportDescription}
    >
      <div className={styles.supportWorkspace}>
        {isInitialLoading ? (
          <AdminStateCard className={styles.supportState} tone="info" title={text.supportLoading} />
        ) : null}

        {ticketsQuery.isError ? (
          <AdminStateCard
            className={styles.supportState}
            tone="danger"
            title={getAdminErrorMessage(ticketsQuery.error, text.loadSupportError)}
            action={
              <div className={styles.supportStateAction}>
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={ticketsQuery.isFetching}
                  onClick={() => void ticketsQuery.refetch().catch(() => undefined)}
                >
                  {retryLabel}
                </Button>
              </div>
            }
          />
        ) : null}

        {!isInitialLoading && !ticketsQuery.isError && !hasTickets ? (
          <section className={styles.supportEmptyState} role="status">
            <strong>{text.supportNoTickets}</strong>
            <p>{text.supportEmptyHint}</p>
          </section>
        ) : null}

        {hasTickets || hasRecoverablePagination ? (
          <>
            <div
              className={styles.supportList}
              hidden={!hasTickets}
              aria-busy={ticketsQuery.isFetching ? "true" : undefined}
              role="list"
            >
              {tickets.map((ticket) => {
                const preview = sanitizeSensitiveText(ticket.lastMessagePreview, 220) || "—";
                const updatedAt = formatDateTime(ticket.updatedAtUtc, locale);
                const ticketStatusLabel = statusLabel(ticket.status, dictionary);
                const ticketPriorityLabel =
                  ticket.priority !== "Normal" ? priorityLabel(ticket.priority, dictionary) : null;
                const assignmentLabel = ticket.assignedAdminDisplayName
                  ? `${text.supportAssignedTo}: ${sanitizeSensitiveText(ticket.assignedAdminDisplayName, 96)}`
                  : text.supportUnassigned;
                const unreadLabel = ticket.unreadForAdmin ? text.supportUnread : null;
                const ticketAccessibleLabel = [
                  text.supportOpenTicket,
                  ticketStatusLabel,
                  ticketPriorityLabel,
                  preview,
                  assignmentLabel,
                  unreadLabel,
                  updatedAt,
                ]
                  .filter(Boolean)
                  .join(". ");

                return (
                  <div key={ticket.conversationId} role="listitem">
                    <Link
                      href={`/${locale}/support/${encodeURIComponent(ticket.conversationId)}`}
                      className={styles.supportTicket}
                      aria-label={ticketAccessibleLabel}
                    >
                      <div className={styles.supportTicketHeader}>
                        <div>
                          <AdminBadge tone={toneForStatus(ticket.status)}>
                            {ticketStatusLabel}
                          </AdminBadge>
                          {ticketPriorityLabel ? (
                            <AdminBadge tone={priorityTone(ticket.priority)}>
                              {ticketPriorityLabel}
                            </AdminBadge>
                          ) : null}
                        </div>
                        <time dateTime={ticket.updatedAtUtc}>{updatedAt}</time>
                      </div>
                      <p>{preview}</p>
                      <div className={styles.supportTicketFooter}>
                        <div className={styles.supportTicketMeta}>
                          <span>{assignmentLabel}</span>
                          {unreadLabel ? (
                            <AdminBadge tone="warning">{text.supportUnread}</AdminBadge>
                          ) : null}
                        </div>
                      </div>
                    </Link>
                  </div>
                );
              })}
            </div>

            {totalPages > 1 || currentPage > 1 ? (
              <div className={styles.supportPagination}>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={currentPage <= 1 || ticketsQuery.isFetching}
                  aria-label={text.supportPreviousPage}
                  title={text.supportPreviousPage}
                  onClick={() =>
                    updatePage((current) => Math.max(1, Math.min(totalPages, current - 1)))
                  }
                >
                  {text.supportPreviousAction}
                </Button>
                <span aria-live="polite">
                  {text.supportPageInfo} {currentPage} / {totalPages}
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={currentPage >= totalPages || ticketsQuery.isFetching}
                  aria-label={text.supportNextPage}
                  title={text.supportNextPage}
                  onClick={() => updatePage((current) => Math.min(totalPages, current + 1))}
                >
                  {text.supportNextAction}
                </Button>
              </div>
            ) : null}
          </>
        ) : null}
      </div>
    </AdminCard>
  );
}
