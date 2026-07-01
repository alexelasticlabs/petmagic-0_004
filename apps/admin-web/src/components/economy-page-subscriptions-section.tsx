import { type ReactNode } from "react";

import {
  AdminCard,
  AdminSelectField,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  eventStatusOptions,
  subscriptionProviderOptions,
  subscriptionStatusOptions,
  type EconomyPageText,
} from "@/components/economy-page.content";
import { canCancelSubscription } from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import {
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  type AdminEconomySubscription,
  type AdminSubscriptionEvent,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type EconomyPageSubscriptionsSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  subscriptionProvider: string;
  subscriptionStatus: string;
  eventProvider: string;
  eventStatus: string;
  subscriptionSearch: string;
  subscriptionPage: number;
  subscriptionsHasMore: boolean;
  subscriptionItems: AdminEconomySubscription[];
  subscriptionsIsFetching: boolean;
  subscriptionsIsRefreshing: boolean;
  cancelSubscriptionPending: boolean;
  subscriptionEvents: AdminSubscriptionEvent[];
  setSubscriptionProvider: (value: string) => void;
  setSubscriptionStatus: (value: string) => void;
  setSubscriptionSearch: (value: string) => void;
  setSubscriptionPage: (value: number | ((current: number) => number)) => void;
  setEventProvider: (value: string) => void;
  setEventStatus: (value: string) => void;
  onCancelSubscription: (subscription: AdminEconomySubscription) => void;
  shortGuid: (value: string) => string;
  humanizeProvider: (value: string, locale: Locale) => string;
  humanizeStatus: (value: string, locale: Locale) => string;
  statusColor: (value: string) => string;
};

function TableOrEmpty({
  hasItems,
  emptyTitle,
  children,
}: {
  hasItems: boolean;
  emptyTitle: string;
  children: ReactNode;
}) {
  if (!hasItems) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <>{children}</>;
}

export function EconomyPageSubscriptionsSection({
  locale,
  text,
  subscriptionProvider,
  subscriptionStatus,
  eventProvider,
  eventStatus,
  subscriptionSearch,
  subscriptionPage,
  subscriptionsHasMore,
  subscriptionItems,
  subscriptionsIsFetching,
  subscriptionsIsRefreshing,
  cancelSubscriptionPending,
  subscriptionEvents,
  setSubscriptionProvider,
  setSubscriptionStatus,
  setSubscriptionSearch,
  setSubscriptionPage,
  setEventProvider,
  setEventStatus,
  onCancelSubscription,
  shortGuid,
  humanizeProvider,
  humanizeStatus,
  statusColor,
}: EconomyPageSubscriptionsSectionProps) {
  return (
    <>
      <AdminCard
        title={text.subscriptionsTitle}
        description={text.subscriptionsDescription}
        action={
          <div className={styles.filterRow}>
            <AdminSelectField
              label={text.providerColumn}
              value={subscriptionProvider}
              onChange={setSubscriptionProvider}
              options={subscriptionProviderOptions[locale]}
              className={styles.compactSelect}
              disabled={subscriptionsIsFetching || subscriptionsIsRefreshing}
            />
            <AdminSelectField
              label={text.statusColumn}
              value={subscriptionStatus}
              onChange={setSubscriptionStatus}
              options={subscriptionStatusOptions[locale]}
              className={styles.compactSelect}
              disabled={subscriptionsIsFetching || subscriptionsIsRefreshing}
            />
            <label className={styles.filterField}>
              <span>{text.searchFilterLabel}</span>
              <input
                className={styles.input}
                disabled={subscriptionsIsFetching || subscriptionsIsRefreshing}
                value={subscriptionSearch}
                onChange={(event) =>
                  setSubscriptionSearch(
                    event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
                  )
                }
                maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
                placeholder={text.subscriptionSearchPlaceholder}
              />
            </label>
          </div>
        }
      >
        {subscriptionsIsRefreshing ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : (
          <TableOrEmpty hasItems={subscriptionItems.length > 0} emptyTitle={text.noSubscriptions}>
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.userColumn}</th>
                    <th>{text.planColumn}</th>
                    <th>{text.providerColumn}</th>
                    <th>{text.statusColumn}</th>
                    <th>{text.renewalColumn}</th>
                    <th>{text.actionsColumn}</th>
                  </tr>
                </thead>
                <tbody>
                  {subscriptionItems.map((item) => (
                    <tr key={item.subscriptionId}>
                      <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{safeText(item.planName || item.planId)}</strong>
                          <span>{`${item.monthlyTokensGranted}/${item.monthlyTokenLimit} ${text.tokensShort}`}</span>
                        </div>
                      </td>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{humanizeProvider(item.provider, locale)}</strong>
                          <span>{`${safeText(item.purchaseChannel, 48)} • ${safeText(item.region, 32)}`}</span>
                        </div>
                      </td>
                      <td>
                        <div className={styles.statusStack}>
                          <AdminStatusBadge color={statusColor(item.status)}>
                            {humanizeStatus(item.status, locale)}
                          </AdminStatusBadge>
                          {item.cancelAtPeriodEnd ? (
                            <AdminStatusBadge color="var(--warning)">
                              {text.cancelAtPeriodEndLabel}
                            </AdminStatusBadge>
                          ) : null}
                        </div>
                      </td>
                      <td>
                        {formatDateTime(item.currentPeriodEndUtc ?? item.updatedAtUtc, locale)}
                      </td>
                      <td>
                        <button
                          type="button"
                          className={styles.dangerButton}
                          disabled={cancelSubscriptionPending || !canCancelSubscription(item)}
                          onClick={() => onCancelSubscription(item)}
                        >
                          {text.cancelSubscriptionAction}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className={styles.pager}>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={subscriptionPage === 0 || subscriptionsIsFetching}
                aria-label={text.previousSubscriptionsPageLabel}
                onClick={() => setSubscriptionPage((current) => Math.max(0, current - 1))}
              >
                {text.previousPage}
              </button>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={!subscriptionsHasMore || subscriptionsIsFetching}
                aria-label={text.nextSubscriptionsPageLabel}
                onClick={() => setSubscriptionPage((current) => current + 1)}
              >
                {text.nextPage}
              </button>
            </div>
          </TableOrEmpty>
        )}
      </AdminCard>

      <AdminCard
        title={text.subscriptionEventsTitle}
        description={text.subscriptionEventsDescription}
        action={
          <div className={styles.filterRow}>
            <AdminSelectField
              label={text.providerColumn}
              value={eventProvider}
              onChange={setEventProvider}
              options={subscriptionProviderOptions[locale]}
              className={styles.compactSelect}
              disabled={subscriptionsIsFetching || subscriptionsIsRefreshing}
            />
            <AdminSelectField
              label={text.statusColumn}
              value={eventStatus}
              onChange={setEventStatus}
              options={eventStatusOptions[locale]}
              className={styles.compactSelect}
              disabled={subscriptionsIsFetching || subscriptionsIsRefreshing}
            />
          </div>
        }
      >
        <TableOrEmpty
          hasItems={subscriptionEvents.length > 0}
          emptyTitle={text.noSubscriptionEvents}
        >
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.timeColumn}</th>
                  <th>{text.providerColumn}</th>
                  <th>{text.eventTypeColumn}</th>
                  <th>{text.statusColumn}</th>
                  <th>{text.processedColumn}</th>
                </tr>
              </thead>
              <tbody>
                {subscriptionEvents.map((item) => (
                  <tr key={item.eventId}>
                    <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                    <td>{humanizeProvider(item.provider, locale)}</td>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{safeText(item.eventType, 80)}</strong>
                        <span>
                          {formatExternalEventId(item.externalEventId, text.noDescription)}
                        </span>
                      </div>
                    </td>
                    <td>
                      <AdminStatusBadge color={statusColor(item.status)}>
                        {humanizeStatus(item.status, locale)}
                      </AdminStatusBadge>
                    </td>
                    <td>
                      {item.processedAtUtc
                        ? formatDateTime(item.processedAtUtc, locale)
                        : text.notProcessedLabel}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </TableOrEmpty>
      </AdminCard>
    </>
  );
}

function safeText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

function formatExternalEventId(value: string | null | undefined, fallback: string) {
  const trimmed = value?.trim();
  if (!trimmed) {
    return fallback;
  }

  const sanitized = sanitizeSensitiveText(trimmed, 96);
  return sanitized.length > 16 ? `${sanitized.slice(0, 8)}...${sanitized.slice(-4)}` : sanitized;
}
