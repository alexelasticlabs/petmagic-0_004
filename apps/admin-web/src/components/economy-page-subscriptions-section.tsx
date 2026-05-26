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
import styles from "@/components/economy-page.module.css";
import { type AdminEconomySubscription, type AdminSubscriptionEvent } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageSubscriptionsSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  subscriptionProvider: string;
  subscriptionStatus: string;
  eventProvider: string;
  eventStatus: string;
  subscriptionItems: AdminEconomySubscription[];
  subscriptionEvents: AdminSubscriptionEvent[];
  setSubscriptionProvider: (value: string) => void;
  setSubscriptionStatus: (value: string) => void;
  setEventProvider: (value: string) => void;
  setEventStatus: (value: string) => void;
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
  subscriptionItems,
  subscriptionEvents,
  setSubscriptionProvider,
  setSubscriptionStatus,
  setEventProvider,
  setEventStatus,
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
            />
            <AdminSelectField
              label={text.statusColumn}
              value={subscriptionStatus}
              onChange={setSubscriptionStatus}
              options={subscriptionStatusOptions[locale]}
              className={styles.compactSelect}
            />
          </div>
        }
      >
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
                </tr>
              </thead>
              <tbody>
                {subscriptionItems.map((item) => (
                  <tr key={item.subscriptionId}>
                    <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{item.planName || item.planId}</strong>
                        <span>{`${item.monthlyTokensGranted}/${item.monthlyTokenLimit} ${text.tokensShort}`}</span>
                      </div>
                    </td>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{humanizeProvider(item.provider, locale)}</strong>
                        <span>{`${item.purchaseChannel} • ${item.region}`}</span>
                      </div>
                    </td>
                    <td>
                      <div className={styles.statusStack}>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {humanizeStatus(item.status, locale)}
                        </AdminStatusBadge>
                        {item.cancelAtPeriodEnd ? (
                          <AdminStatusBadge color="#f59e0b">
                            {text.cancelAtPeriodEndLabel}
                          </AdminStatusBadge>
                        ) : null}
                      </div>
                    </td>
                    <td>{formatDateTime(item.currentPeriodEndUtc ?? item.updatedAtUtc, locale)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </TableOrEmpty>
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
            />
            <AdminSelectField
              label={text.statusColumn}
              value={eventStatus}
              onChange={setEventStatus}
              options={eventStatusOptions[locale]}
              className={styles.compactSelect}
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
                        <strong>{item.eventType}</strong>
                        <span>
                          {item.externalSubscriptionId ||
                            item.externalEventId ||
                            text.noDescription}
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
