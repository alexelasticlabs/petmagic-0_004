"use client";

import Link from "next/link";

import {
  BellIcon,
  CancelCircleIcon,
  CaretDownIcon,
  ClockIcon,
  PlayCircleIcon,
  SupportIcon,
} from "@/components/admin/admin-icons";
import { AdminStateCard } from "@/components/admin/admin-primitives";
import paletteStyles from "@/components/support/support-conversation-chat-content.module.css";
import {
  formatClockTime,
  formatRelativeTime,
  formatSafeSupportDisplay,
  getConversationSla,
  initialsFor,
  shortId,
} from "@/components/support/support-conversation-helpers";
import styles from "@/components/support/support-conversation-queue-pane.module.css";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { sourceLabel, statusLabel } from "@/components/support/support-status-helpers";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import type {
  AdminSupportConversationSummary,
  SupportConversationPriority,
  SupportConversationStatus,
  SupportInboxSort,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { maskEmail } from "@/lib/sensitive-display";

type SupportConversationQueuePaneProps = {
  archiveCount: number;
  canManageSupportWorkspace: boolean;
  canGoToNextQueuePage: boolean;
  canGoToPreviousQueuePage: boolean;
  conversationId: string;
  deletedUserName: string;
  displayedInboxItems: AdminSupportConversationSummary[];
  incomingMessagesCount: number;
  inboxCurrentPage: number;
  inboxQueryIsError: boolean;
  inboxQueryIsFetching: boolean;
  inboxQueryIsLoading: boolean;
  inboxTotalCount: number;
  isQueueControlsLocked: boolean;
  locale: Locale;
  navigationMode: "route" | "local";
  onConversationSelect?: (conversationId: string) => void;
  queueCount: number;
  queueLabels: ReturnType<typeof getSupportConversationCopy>["page"]["queue"];
  queuePriorityFilter: "all" | SupportConversationPriority;
  queueShownEnd: number;
  queueShownStart: number;
  queueSort: SupportInboxSort;
  queueStatusFilter: "all" | SupportConversationStatus;
  requestInboxRetry: () => void;
  requestNextQueuePage: () => void;
  requestPreviousQueuePage: () => void;
  setExactQueuePriorityFilter: (value: "all" | SupportConversationPriority) => void;
  setExactQueueSort: (value: SupportInboxSort) => void;
  setExactQueueStatusFilter: (value: "all" | SupportConversationStatus) => void;
  setQueueSubFilter: (value: "all" | "waiting" | "unassigned" | "archive") => void;
  subFilter: "all" | "waiting" | "unassigned" | "archive";
  text: ReturnType<typeof getDictionary>;
  unassignedCount: number;
};

function avatarColorFor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash + name.charCodeAt(i)) % 8;
  }
  return (
    paletteStyles[`avatarColor${hash}` as keyof typeof paletteStyles] ?? paletteStyles.avatarColor6
  );
}

function QueueStatusIcon({ status }: { status: SupportConversationStatus }) {
  if (status === "New") {
    return <BellIcon className={styles.queueStatusIcon} />;
  }
  if (status === "InProgress") {
    return <PlayCircleIcon className={styles.queueStatusIcon} />;
  }
  if (status === "WaitingForUser") {
    return <ClockIcon className={styles.queueStatusIcon} />;
  }
  return <CancelCircleIcon className={styles.queueStatusIcon} />;
}

export function SupportConversationQueuePane({
  archiveCount,
  canManageSupportWorkspace,
  canGoToNextQueuePage,
  canGoToPreviousQueuePage,
  conversationId,
  deletedUserName,
  displayedInboxItems,
  incomingMessagesCount,
  inboxCurrentPage,
  inboxQueryIsError,
  inboxQueryIsFetching,
  inboxQueryIsLoading,
  inboxTotalCount,
  isQueueControlsLocked,
  locale,
  navigationMode,
  onConversationSelect,
  queueCount,
  queueLabels,
  queuePriorityFilter,
  queueShownEnd,
  queueShownStart,
  queueSort,
  queueStatusFilter,
  requestInboxRetry,
  requestNextQueuePage,
  requestPreviousQueuePage,
  setExactQueuePriorityFilter,
  setExactQueueSort,
  setExactQueueStatusFilter,
  setQueueSubFilter,
  subFilter,
  text,
  unassignedCount,
}: SupportConversationQueuePaneProps) {
  return (
    <div className={styles.inboxPaneFlat}>
      <div className={styles.queuePaneHeader}>
        <div className={styles.queuePaneTitleRow}>
          <h2 className={styles.queuePaneTitle}>{queueLabels.title}</h2>
          <span className={styles.paneCountBadge}>
            {subFilter === "archive" ? archiveCount : queueCount}
          </span>
          {incomingMessagesCount > 0 ? (
            <span
              className={`${styles.queueCountBadge} ${styles.queueCountBadgeIncoming}`}
              title={queueLabels.newMessagesTitle(incomingMessagesCount)}
            >
              <SupportIcon className={styles.queueBadgeIcon} />
              {incomingMessagesCount}
            </span>
          ) : null}
        </div>
      </div>

      <div className={styles.queueSubFilters}>
        <button
          type="button"
          className={subFilter === "all" ? styles.queueSubFilterActive : styles.queueSubFilter}
          disabled={isQueueControlsLocked}
          onClick={() => setQueueSubFilter("all")}
        >
          {queueLabels.all} {queueCount}
        </button>
        <button
          type="button"
          className={subFilter === "waiting" ? styles.queueSubFilterActive : styles.queueSubFilter}
          disabled={isQueueControlsLocked}
          onClick={() => setQueueSubFilter("waiting")}
        >
          {queueLabels.waiting}
        </button>
        <button
          type="button"
          className={
            subFilter === "unassigned" ? styles.queueSubFilterActive : styles.queueSubFilter
          }
          disabled={isQueueControlsLocked}
          onClick={() => setQueueSubFilter("unassigned")}
        >
          {queueLabels.unassigned} {unassignedCount}
        </button>
        <button
          type="button"
          className={subFilter === "archive" ? styles.queueSubFilterActive : styles.queueSubFilter}
          disabled={isQueueControlsLocked}
          onClick={() => setQueueSubFilter("archive")}
        >
          {queueLabels.archive} {archiveCount}
        </button>
      </div>

      <div className={styles.queueFiltersGrid}>
        <label className={styles.queueToolField}>
          <span>{queueLabels.status}</span>
          <Select
            value={queueStatusFilter}
            disabled={isQueueControlsLocked}
            onChange={(value) => {
              setExactQueueStatusFilter(value as "all" | SupportConversationStatus);
            }}
            showSelectedDescription={false}
            options={[
              { value: "all", label: queueLabels.all },
              { value: "New", label: statusLabel("New", text) },
              { value: "InProgress", label: statusLabel("InProgress", text) },
              { value: "WaitingForUser", label: statusLabel("WaitingForUser", text) },
              { value: "Closed", label: statusLabel("Closed", text) },
            ]}
          />
        </label>
        <label className={styles.queueToolField}>
          <span>{queueLabels.priority}</span>
          <Select
            value={queuePriorityFilter}
            disabled={isQueueControlsLocked}
            onChange={(value) => {
              setExactQueuePriorityFilter(value as "all" | SupportConversationPriority);
            }}
            showSelectedDescription={false}
            options={[
              { value: "all", label: queueLabels.priorityAll },
              { value: "High", label: queueLabels.priorityHigh },
              { value: "Normal", label: queueLabels.priorityNormal },
              { value: "Low", label: queueLabels.priorityLow },
            ]}
          />
        </label>
        <label className={styles.queueToolField}>
          <span>{queueLabels.sort}</span>
          <Select
            value={queueSort}
            disabled={isQueueControlsLocked}
            onChange={(value) => {
              setExactQueueSort(value as SupportInboxSort);
            }}
            showSelectedDescription={false}
            options={[
              { value: "default", label: queueLabels.sortDefault },
              { value: "priority", label: queueLabels.sortPriority },
              { value: "waiting", label: queueLabels.sortWaiting },
              { value: "updated", label: queueLabels.sortUpdated },
              { value: "created", label: queueLabels.sortCreated },
            ]}
          />
        </label>
      </div>

      {inboxQueryIsLoading ? (
        <AdminStateCard tone="info" title={text.loading} />
      ) : inboxQueryIsError ? (
        <AdminStateCard
          tone="danger"
          title={text.supportLoadError}
          action={
            <Button
              variant="secondary"
              size="sm"
              onClick={requestInboxRetry}
              disabled={!canManageSupportWorkspace || inboxQueryIsFetching}
            >
              {text.supportRetryAction}
            </Button>
          }
        />
      ) : displayedInboxItems.length === 0 ? (
        <AdminStateCard tone="info" title={text.supportEmpty} />
      ) : (
        <div className={styles.list} role="list">
          {displayedInboxItems.map((item) => {
            const itemSla = getConversationSla(
              item.waitingSinceUtc ?? item.lastMessageAtUtc ?? item.createdAtUtc,
              locale,
              item.adminUnreadCount
            );
            const hasUnread = item.adminUnreadCount > 0;
            const queueUserLabel = item.userDisplayName?.trim()
              ? formatSafeSupportDisplay(item.userDisplayName, "", 72)
              : (item.userEmail?.trim() ? maskEmail(item.userEmail) : "") || deletedUserName;

            const queueItemClassName = `${styles.conversationRow} ${item.isReadOnly ? styles.conversationRowClosed : ""} ${item.conversationId === conversationId ? styles.conversationRowActive : ""} ${hasUnread ? styles.conversationRowUnread : ""}`;
            const queueItemContent = (
              <>
                <div className={styles.queueRowHeader}>
                  <div className={styles.queueRowIdentity}>
                    <span
                      className={`${styles.avatar} ${avatarColorFor(queueUserLabel)}`}
                      aria-hidden="true"
                    >
                      {initialsFor(queueUserLabel)}
                    </span>
                    <div className={styles.queueRowTextStack}>
                      <div className={styles.queueRowTitleLine}>
                        <div
                          className={`${styles.rowTitle} ${hasUnread ? styles.rowTitleUnread : ""}`}
                        >
                          {queueUserLabel}
                        </div>
                        {hasUnread ? (
                          <span className={styles.unreadDotInline} aria-hidden="true" />
                        ) : null}
                      </div>
                      <div className={styles.rowPreview}>
                        <span>
                          {formatSupportMessagePreview(
                            item.lastMessagePreview,
                            text.supportNoMessages
                          )}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className={styles.queueRowMeta}>
                    <span className={styles.rowTime}>
                      {item.lastMessageAtUtc
                        ? formatClockTime(item.lastMessageAtUtc, locale)
                        : formatRelativeTime(item.updatedAtUtc, locale)}
                    </span>
                    <div className={styles.queueRowCounters}>
                      {item.userUnreadCount > 0 ? (
                        <span
                          className={`${styles.queueCountBadge} ${styles.queueCountBadgeIncoming}`}
                          title={queueLabels.userUnreadTitle(item.userUnreadCount)}
                        >
                          <SupportIcon className={styles.queueBadgeIcon} />
                          {item.userUnreadCount}
                        </span>
                      ) : null}
                      {item.adminUnreadCount > 0 ? (
                        <span
                          className={`${styles.queueCountBadge} ${styles.queueCountBadgeUnread}`}
                          title={queueLabels.adminUnreadTitle(item.adminUnreadCount)}
                        >
                          <BellIcon className={styles.queueBadgeIcon} />
                          {item.adminUnreadCount}
                        </span>
                      ) : null}
                    </div>
                  </div>
                </div>
                <div className={styles.queueRowFooter}>
                  <span
                    className={`${styles.queueStatusPill} ${styles[`queueStatusPill_${item.status}` as keyof typeof styles]}`}
                  >
                    <QueueStatusIcon status={item.status} />
                    {statusLabel(item.status, text)}
                  </span>
                  {itemSla.waitLabel ? (
                    <span className={`${styles.slaPill} ${styles[`slaPill_${itemSla.level}`]}`}>
                      {itemSla.waitLabel}
                    </span>
                  ) : null}
                </div>
                <div className={styles.queueRowDetailLine}>
                  <span className={styles.queueMetaChip}>{sourceLabel(item.source, text)}</span>
                  <span className={styles.queueMetaChipMuted}>
                    #{shortId(item.initiatorUserId)}
                  </span>
                  <span className={styles.queueMetaChipMuted}>
                    {item.assignedAdminDisplayName?.trim()
                      ? queueLabels.assignedOperator(
                          formatSafeSupportDisplay(item.assignedAdminDisplayName, "", 72)
                        )
                      : queueLabels.unassignedOperator}
                  </span>
                </div>
              </>
            );

            if (navigationMode === "local") {
              return (
                <button
                  key={item.conversationId}
                  type="button"
                  role="listitem"
                  aria-current={item.conversationId === conversationId ? "page" : undefined}
                  className={`${queueItemClassName} ${styles.conversationRowButton}`}
                  disabled={isQueueControlsLocked}
                  onClick={() => {
                    if (isQueueControlsLocked) {
                      return;
                    }

                    onConversationSelect?.(item.conversationId);
                  }}
                >
                  {queueItemContent}
                </button>
              );
            }

            const supportConversationPathId = encodeURIComponent(item.conversationId);
            return (
              <Link
                key={item.conversationId}
                href={`/${locale}/support/${supportConversationPathId}`}
                role="listitem"
                aria-current={item.conversationId === conversationId ? "page" : undefined}
                className={queueItemClassName}
                data-disabled={isQueueControlsLocked ? "true" : undefined}
                tabIndex={isQueueControlsLocked ? -1 : undefined}
                onClick={(event) => {
                  if (isQueueControlsLocked) {
                    event.preventDefault();
                  }
                }}
              >
                {queueItemContent}
              </Link>
            );
          })}
        </div>
      )}
      {!inboxQueryIsLoading &&
      !inboxQueryIsError &&
      (displayedInboxItems.length > 0 || inboxCurrentPage > 1) ? (
        <div className={styles.queueFooter}>
          <span className={styles.queueFooterCount}>
            {queueLabels.pageCount(
              inboxCurrentPage,
              queueShownStart,
              queueShownEnd,
              inboxTotalCount
            )}
          </span>
          <div className={styles.queuePagerActions}>
            <button
              type="button"
              className={styles.queuePagerButton}
              disabled={!canGoToPreviousQueuePage || isQueueControlsLocked}
              aria-label={queueLabels.previousPage}
              title={queueLabels.previousPage}
              onClick={requestPreviousQueuePage}
            >
              <CaretDownIcon
                className={`${styles.queuePagerIcon} ${styles.queuePagerIconPrevious}`}
              />
            </button>
            <button
              type="button"
              className={styles.queuePagerButton}
              disabled={!canGoToNextQueuePage || isQueueControlsLocked}
              aria-label={queueLabels.nextPage}
              title={queueLabels.nextPage}
              onClick={requestNextQueuePage}
            >
              <CaretDownIcon className={`${styles.queuePagerIcon} ${styles.queuePagerIconNext}`} />
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
