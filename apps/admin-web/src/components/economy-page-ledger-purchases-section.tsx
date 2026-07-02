"use client";

import {
  AdminCard,
  AdminPageGrid,
  AdminSelectField,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  ledgerSourceOptions,
  purchaseStatusOptions,
  subscriptionProviderOptions,
  type EconomyPageText,
} from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  TableOrEmpty,
  formatCurrency,
  humanizeProvider,
  humanizeSource,
  humanizeStatus,
  safeText,
  shortGuid,
  statusColor,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import {
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  type AdminEconomyLedgerItem,
  type AdminEconomyPurchase,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageLedgerPurchasesSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  ledgerSource: string;
  setLedgerSource: (value: string) => void;
  ledgerItems: AdminEconomyLedgerItem[];
  ledgerPage: number;
  ledgerHasMore: boolean;
  ledgerIsFetching: boolean;
  ledgerIsRefreshing: boolean;
  setLedgerPage: (value: number | ((current: number) => number)) => void;
  purchaseStatus: string;
  setPurchaseStatus: (value: string) => void;
  purchaseProvider: string;
  setPurchaseProvider: (value: string) => void;
  purchaseSearch: string;
  setPurchaseSearch: (value: string) => void;
  purchasesIsFetching: boolean;
  purchasesIsRefreshing: boolean;
  purchaseItems: AdminEconomyPurchase[];
  purchasePage: number;
  purchasesHasMore: boolean;
  setPurchasePage: (value: number | ((current: number) => number)) => void;
  isRefundPurchaseSubmitting: boolean;
  onRefundPurchase: (purchase: AdminEconomyPurchase) => void;
};

export function EconomyPageLedgerPurchasesSection({
  locale,
  text,
  ledgerSource,
  setLedgerSource,
  ledgerItems,
  ledgerPage,
  ledgerHasMore,
  ledgerIsFetching,
  ledgerIsRefreshing,
  setLedgerPage,
  purchaseStatus,
  setPurchaseStatus,
  purchaseProvider,
  setPurchaseProvider,
  purchaseSearch,
  setPurchaseSearch,
  purchasesIsFetching,
  purchasesIsRefreshing,
  purchaseItems,
  purchasePage,
  purchasesHasMore,
  setPurchasePage,
  isRefundPurchaseSubmitting,
  onRefundPurchase,
}: EconomyPageLedgerPurchasesSectionProps) {
  return (
    <AdminPageGrid columns="two">
      <AdminCard
        title={text.ledgerTitle}
        description={text.ledgerDescription}
        action={
          <AdminSelectField
            label={text.ledgerFilterLabel}
            value={ledgerSource}
            onChange={setLedgerSource}
            options={ledgerSourceOptions[locale]}
            className={styles.compactSelect}
          />
        }
      >
        {ledgerIsRefreshing ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : (
          <TableOrEmpty hasItems={ledgerItems.length > 0} emptyTitle={text.noLedger}>
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.timeColumn}</th>
                    <th>{text.userColumn}</th>
                    <th>{text.deltaColumn}</th>
                    <th>{text.balanceColumn}</th>
                    <th>{text.sourceColumn}</th>
                    <th>{text.tokenKindColumn}</th>
                    <th>{text.operationKindColumn}</th>
                    <th>{text.expiryColumn}</th>
                    <th>{text.reasonColumn}</th>
                    <th>{text.bucketAllocationColumn}</th>
                  </tr>
                </thead>
                <tbody>
                  {ledgerItems.map((item) => (
                    <tr key={item.entryId}>
                      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                      <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                      <td>
                        <span className={item.delta >= 0 ? styles.positive : styles.negative}>
                          {item.delta >= 0 ? "+" : ""}
                          {item.delta}
                        </span>
                      </td>
                      <td>{item.balanceAfter}</td>
                      <td>{humanizeSource(item.source, locale)}</td>
                      <td>{safeText(item.tokenKind ?? "legacy", 64)}</td>
                      <td>{safeText(item.operationKind ?? "-", 64)}</td>
                      <td>
                        {item.expiresAtUtc ? formatDateTime(item.expiresAtUtc, locale) : "-"}
                      </td>
                      <td>{safeText(item.reason)}</td>
                      <td>{safeText(item.bucketDeltasJson ?? "-", 160)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className={styles.pager}>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={ledgerPage === 0 || ledgerIsFetching}
                aria-label={text.previousLedgerPageLabel}
                onClick={() => setLedgerPage((current) => Math.max(0, current - 1))}
              >
                {text.previousPage}
              </button>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={!ledgerHasMore || ledgerIsFetching}
                aria-label={text.nextLedgerPageLabel}
                onClick={() => setLedgerPage((current) => current + 1)}
              >
                {text.nextPage}
              </button>
            </div>
          </TableOrEmpty>
        )}
      </AdminCard>

      <AdminCard
        title={text.purchasesTitle}
        description={text.purchasesDescription}
        action={
          <div className={styles.filterRow}>
            <AdminSelectField
              label={text.purchaseFilterLabel}
              value={purchaseStatus}
              onChange={setPurchaseStatus}
              options={purchaseStatusOptions[locale]}
              className={styles.compactSelect}
              disabled={purchasesIsFetching || purchasesIsRefreshing}
            />
            <AdminSelectField
              label={text.purchaseProviderFilterLabel}
              value={purchaseProvider}
              onChange={setPurchaseProvider}
              options={subscriptionProviderOptions[locale]}
              className={styles.compactSelect}
              disabled={purchasesIsFetching || purchasesIsRefreshing}
            />
            <label className={styles.filterField}>
              <span>{text.searchFilterLabel}</span>
              <input
                className={styles.input}
                disabled={purchasesIsFetching || purchasesIsRefreshing}
                value={purchaseSearch}
                onChange={(event) =>
                  setPurchaseSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))
                }
                maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
                placeholder={text.purchaseSearchPlaceholder}
              />
            </label>
          </div>
        }
      >
        {purchasesIsRefreshing ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : (
          <TableOrEmpty hasItems={purchaseItems.length > 0} emptyTitle={text.noPurchases}>
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.timeColumn}</th>
                    <th>{text.userColumn}</th>
                    <th>{text.productTypeColumn}</th>
                    <th>{text.packColumn}</th>
                    <th>{text.providerColumn}</th>
                    <th>{text.amountColumn}</th>
                    <th>{text.statusColumn}</th>
                    <th>{text.refundStatusColumn}</th>
                    <th>{text.actionsColumn}</th>
                  </tr>
                </thead>
                <tbody>
                  {purchaseItems.map((item) => {
                    const canRefund =
                      item.canRefund === true &&
                      item.status !== "refunded" &&
                      item.status !== "failed";

                    return (
                      <tr key={item.orderId}>
                        <td>{formatDateTime(item.confirmedAtUtc ?? item.createdAtUtc, locale)}</td>
                        <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                        <td>{safeText(item.productType ?? "TokenPack")}</td>
                        <td>
                          <div className={styles.packMeta}>
                            <strong>{safeText(item.packDisplayName)}</strong>
                            <span>
                              {item.tokenAmount ?? item.sparkToGrant} {text.tokensShort}
                            </span>
                          </div>
                        </td>
                        <td>{humanizeProvider(item.paymentProvider, locale)}</td>
                        <td>{formatCurrency(item.priceAmount, locale, item.currencyCode)}</td>
                        <td>
                          <AdminStatusBadge color={statusColor(item.status)}>
                            {humanizeStatus(item.status, locale)}
                          </AdminStatusBadge>
                        </td>
                        <td>
                          {safeText(
                            item.refundStatus ?? (item.status === "refunded" ? "refunded" : "none")
                          )}
                        </td>
                        <td>
                          {canRefund ? (
                            <Button
                              type="button"
                              size="sm"
                              variant="danger"
                              disabled={isRefundPurchaseSubmitting}
                              onClick={() => onRefundPurchase(item)}
                            >
                              {text.refundPurchaseAction}
                            </Button>
                          ) : (
                            <span className={styles.mutedText}>-</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <div className={styles.pager}>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={purchasePage === 0 || purchasesIsFetching}
                aria-label={text.previousPurchasesPageLabel}
                onClick={() => setPurchasePage((current) => Math.max(0, current - 1))}
              >
                {text.previousPage}
              </button>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={!purchasesHasMore || purchasesIsFetching}
                aria-label={text.nextPurchasesPageLabel}
                onClick={() => setPurchasePage((current) => current + 1)}
              >
                {text.nextPage}
              </button>
            </div>
          </TableOrEmpty>
        )}
      </AdminCard>
    </AdminPageGrid>
  );
}
