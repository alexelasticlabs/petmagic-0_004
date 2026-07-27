"use client";

import Link from "next/link";

import {
  BellIcon,
  CancelCircleIcon,
  CaretDownIcon,
  ClockIcon,
  PlayCircleIcon,
  SearchIcon,
  SupportIcon,
} from "@/components/admin/admin-icons";
import { AdminStateCard } from "@/components/admin/admin-primitives";
import paletteStyles from "@/components/support/support-conversation-chat-content.module.css";
import { type SupportQueueSubFilter } from "@/components/support/support-conversation-controller.helpers";
import {
  formatClockTime,
  formatRelativeTime,
  formatSafeSupportDisplay,
  getConversationSla,
  initialsFor,
} from "@/components/support/support-conversation-helpers";
import styles from "@/components/support/support-conversation-queue-pane.module.css";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { statusLabel } from "@/components/support/support-status-helpers";
import { SUPPORT_SEARCH_MAX_LENGTH } from "@/components/support/use-support-conversation-controller";
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

import type { RefObject } from "react";

type SupportConversationQueuePaneProps = {
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
  queueSearchParams: string;
  queuePriorityFilter: "all" | SupportConversationPriority;
  queueShownEnd: number;
  queueShownStart: number;
  queueSort: SupportInboxSort;
  queueStatusFilter: "all" | SupportConversationStatus;
  requestInboxRetry: () => void;
  requestNextQueuePage: () => void;
  requestPreviousQueuePage: () => void;
  searchInputRef: RefObject<HTMLInputElement | null>;
  searchQuery: string;
  setExactQueuePriorityFilter: (value: "all" | SupportConversationPriority) => void;
  setExactQueueSort: (value: SupportInboxSort) => void;
  setExactQueueStatusFilter: (value: "all" | SupportConversationStatus) => void;
  setQueueSubFilter: (value: SupportQueueSubFilter) => void;
  setSearchQuery: (value: string) => void;
  subFilter: SupportQueueSubFilter;
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
  queueSearchParams,
  queuePriorityFilter,
  queueShownEnd,
  queueShownStart,
  queueSort,
  queueStatusFilter,
  requestInboxRetry,
  requestNextQueuePage,
  requestPreviousQueuePage,
  searchInputRef,
  searchQuery,
  setExactQueuePriorityFilter,
  setExactQueueSort,
  setExactQueueStatusFilter,
  setQueueSubFilter,
  setSearchQuery,
  subFilter,
  text,
  unassignedCount,
}: SupportConversationQueuePaneProps) {
  const activeAdvancedFilterCount =
    Number(queueStatusFilter !== "all") +
    Number(queuePriorityFilter !== "all") +
    Number(queueSort !== "default");
  const filterSummary =
    activeAdvancedFilterCount > 0
      ? queueLabels.filtersActive(activeAdvancedFilterCount)
      : queueLabels.filters;

  return (
    <div className={styles.inboxPaneFlat} data-testid="support-queue-pane">
      <div className={styles.queuePaneHeader}>
        <div className={styles.queuePaneTitleRow}>
          <h2 className={styles.queuePaneTitle}>{queueLabels.title}</h2>
          <span className={styles.paneCountBadge}>{queueCount}</span>
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

      <label className={styles.queueSearchField}>
        <span className={styles.queueSearchIcon} aria-hidden="true">
          <SearchIcon />
        </span>
        <span className={styles.queueSearchLabel}>{text.supportSearchPlaceholder}</span>
        <input
          ref={searchInputRef}
          className={styles.queueSearchInput}
          value={searchQuery}
          onChange={(event) => setSearchQuery(event.target.value)}
          maxLength={SUPPORT_SEARCH_MAX_LENGTH}
          placeholder={text.supportSearchPlaceholder}
          aria-label={text.supportSearchPlaceholder}
          title={text.supportSearchKeyboardHint}
        />
        <span className={styles.queueSearchShortcut} aria-hidden="true">
          /
        </span>
      </label>

      <div className={styles.queueQuickActions}>
        <button
          type="button"
          className={
            subFilter === "unread" ? styles.queueQuickFilterActive : styles.queueQuickFilter
          }
          disabled={isQueueControlsLocked}
          aria-pressed={subFilter === "unread"}
          onClick={() => setQueueSubFilter(subFilter === "unread" ? "all" : "unread")}
        >
          {queueLabels.unread} {incomingMessagesCount}
        </button>
        <button
          type="button"
          className={
            subFilter === "unassigned" ? styles.queueQuickFilterActive : styles.queueQuickFilter
          }
          disabled={isQueueControlsLocked}
          aria-pressed={subFilter === "unassigned"}
          onClick={() => setQueueSubFilter(subFilter === "unassigned" ? "all" : "unassigned")}
        >
          {queueLabels.unassigned} {unassignedCount}
        </button>
      </div>

      <details
        className={styles.queueFiltersDisclosure}
        open={activeAdvancedFilterCount > 0 ? true : undefined}
      >
        <summary className={styles.queueFiltersSummary}>
          <span>{filterSummary}</span>
          {activeAdvancedFilterCount > 0 ? (
            <span className={styles.queueFiltersSummaryCount}>{activeAdvancedFilterCount}</span>
          ) : null}
          <CaretDownIcon className={styles.queueFiltersSummaryIcon} />
        </summary>
        <div className={styles.queueFiltersGrid}>
          <label className={styles.queueToolField}>
            <span>{queueLabels.status}</span>
            <Select
              value={queueStatusFilter}
              ariaLabel={queueLabels.status}
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
              ariaLabel={queueLabels.priority}
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
              ariaLabel={queueLabels.sort}
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
      </details>

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
              item.adminUnreadCount,
              item.sla
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
            const supportConversationSearchSuffix = queueSearchParams
              ? `?${queueSearchParams}`
              : "";
            return (
              <Link
                key={item.conversationId}
                href={`/${locale}/support/${supportConversationPathId}${supportConversationSearchSuffix}`}
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
