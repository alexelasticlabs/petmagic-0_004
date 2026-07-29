"use client";

import { useState } from "react";

import {
  AdminDataSurface,
  AdminFilterBar,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { EconomySelectField } from "@/components/economy-page-select-field";
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
  humanizeTokenKind,
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

const RECENT_ITEMS_LIMIT = 5;

function formatCompactDateTime(value: string, locale: Locale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    month: "short",
  }).format(new Date(value));
}

type EconomyPageLedgerPurchasesSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  ledgerSource: string;
  setLedgerSource: (value: string) => void;
  ledgerItems: AdminEconomyLedgerItem[];
  ledgerPage: number;
  ledgerHasMore: boolean;
  ledgerIsFetching: boolean;
  setLedgerPage: (value: number | ((current: number) => number)) => void;
  purchaseStatus: string;
  setPurchaseStatus: (value: string) => void;
  purchaseProvider: string;
  setPurchaseProvider: (value: string) => void;
  purchaseSearch: string;
  setPurchaseSearch: (value: string) => void;
  purchasesIsFetching: boolean;
  purchaseItems: AdminEconomyPurchase[];
  purchasePage: number;
  purchasesHasMore: boolean;
  setPurchasePage: (value: number | ((current: number) => number)) => void;
  isRefundPurchaseSubmitting: boolean;
  onRefundPurchase: (purchase: AdminEconomyPurchase) => void;
  onInspectPurchase: (purchase: AdminEconomyPurchase) => void;
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
  setLedgerPage,
  purchaseStatus,
  setPurchaseStatus,
  purchaseProvider,
  setPurchaseProvider,
  purchaseSearch,
  setPurchaseSearch,
  purchasesIsFetching,
  purchaseItems,
  purchasePage,
  purchasesHasMore,
  setPurchasePage,
  isRefundPurchaseSubmitting,
  onRefundPurchase,
  onInspectPurchase,
}: EconomyPageLedgerPurchasesSectionProps) {
  const [showLedgerDetails, setShowLedgerDetails] = useState(false);
  const [showPurchaseDetails, setShowPurchaseDetails] = useState(false);
  const [showLedgerFilters, setShowLedgerFilters] = useState(false);
  const [showPurchaseFilters, setShowPurchaseFilters] = useState(false);
  const ledgerFilterCount = ledgerSource ? 1 : 0;
  const purchaseFilterCount =
    Number(Boolean(purchaseStatus)) +
    Number(Boolean(purchaseProvider)) +
    Number(Boolean(purchaseSearch.trim()));
  const shouldShowLedgerFilters = showLedgerFilters || ledgerFilterCount > 0;
  const shouldShowPurchaseFilters = showPurchaseFilters || purchaseFilterCount > 0;

  return (
    <div className={styles.overviewDataGrid}>
      <AdminDataSurface
        title={text.recentActivityTitle}
        description={text.recentActivityDescription}
        className={styles.overviewDataCard}
        action={
          <div className={styles.overviewCardActions}>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              aria-expanded={shouldShowLedgerFilters}
              aria-controls="economy-ledger-filters"
              onClick={() => setShowLedgerFilters((current) => !current)}
            >
              {ledgerFilterCount
                ? `${text.filtersAction} · ${ledgerFilterCount}`
                : text.filtersAction}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              aria-expanded={showLedgerDetails}
              aria-controls={showLedgerDetails ? "economy-ledger-details" : undefined}
              onClick={() => setShowLedgerDetails((current) => !current)}
            >
              {showLedgerDetails ? text.collapseDetailsAction : text.allLedgerAction}
            </Button>
          </div>
        }
      >
        <div id="economy-ledger-filters" hidden={!shouldShowLedgerFilters}>
          <AdminFilterBar className={styles.tableFilterBar}>
            <EconomySelectField
              label={text.ledgerFilterLabel}
              value={ledgerSource}
              onChange={setLedgerSource}
              options={ledgerSourceOptions[locale]}
              className={styles.compactSelect}
              disabled={ledgerIsFetching && ledgerItems.length === 0}
            />
          </AdminFilterBar>
        </div>
        {ledgerIsFetching && ledgerItems.length === 0 ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : (
          <TableOrEmpty hasItems={ledgerItems.length > 0} emptyTitle={text.noLedger}>
            {showLedgerDetails ? (
              <div id="economy-ledger-details">
                <div className={adminTableStyles.tableWrap} aria-busy={ledgerIsFetching}>
                  <table className={`${adminTableStyles.table} ${styles.wideTable}`}>
                    <thead>
                      <tr>
                        <th scope="col">{text.timeColumn}</th>
                        <th scope="col">{text.userColumn}</th>
                        <th scope="col">{text.deltaColumn}</th>
                        <th scope="col">{text.balanceColumn}</th>
                        <th scope="col">{text.sourceColumn}</th>
                        <th scope="col">{text.tokenKindColumn}</th>
                        <th scope="col">{text.operationKindColumn}</th>
                        <th scope="col">{text.expiryColumn}</th>
                        <th scope="col">{text.reasonColumn}</th>
                        <th scope="col">{text.bucketAllocationColumn}</th>
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
                          <td>
                            {humanizeTokenKind(item.tokenKind, locale, text.tokenKindLegacyLabel)}
                          </td>
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
              </div>
            ) : (
              <ol className={styles.overviewActivityList} aria-busy={ledgerIsFetching}>
                {ledgerItems.slice(0, RECENT_ITEMS_LIMIT).map((item) => (
                  <li key={item.entryId} className={styles.overviewActivityItem}>
                    <time className={styles.overviewActivityTime} dateTime={item.createdAtUtc}>
                      {formatCompactDateTime(item.createdAtUtc, locale)}
                    </time>
                    <div className={styles.overviewActivityCopy}>
                      <strong title={humanizeSource(item.source, locale)}>
                        {humanizeSource(item.source, locale)}
                      </strong>
                      <span title={safeText(item.reason, 160)}>{safeText(item.reason, 96)}</span>
                    </div>
                    <div className={styles.overviewActivityValue}>
                      <strong className={item.delta >= 0 ? styles.positive : styles.negative}>
                        {item.delta >= 0 ? "+" : ""}
                        {item.delta}
                      </strong>
                      <span>
                        {text.balanceColumn}: {item.balanceAfter}
                      </span>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </TableOrEmpty>
        )}
      </AdminDataSurface>

      <AdminDataSurface
        title={text.recentPurchasesTitle}
        description={text.recentPurchasesDescription}
        className={styles.overviewDataCard}
        action={
          <div className={styles.overviewCardActions}>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              aria-expanded={shouldShowPurchaseFilters}
              aria-controls="economy-purchase-filters"
              onClick={() => setShowPurchaseFilters((current) => !current)}
            >
              {purchaseFilterCount
                ? `${text.filtersAction} · ${purchaseFilterCount}`
                : text.filtersAction}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              aria-expanded={showPurchaseDetails}
              aria-controls={showPurchaseDetails ? "economy-purchase-details" : undefined}
              onClick={() => setShowPurchaseDetails((current) => !current)}
            >
              {showPurchaseDetails ? text.collapseDetailsAction : text.allPurchasesAction}
            </Button>
          </div>
        }
      >
        <div id="economy-purchase-filters" hidden={!shouldShowPurchaseFilters}>
          <AdminFilterBar className={styles.tableFilterBar}>
            <EconomySelectField
              label={text.purchaseFilterLabel}
              value={purchaseStatus}
              onChange={setPurchaseStatus}
              options={purchaseStatusOptions[locale]}
              className={styles.compactSelect}
              disabled={purchasesIsFetching && purchaseItems.length === 0}
            />
            <EconomySelectField
              label={text.purchaseProviderFilterLabel}
              value={purchaseProvider}
              onChange={setPurchaseProvider}
              options={subscriptionProviderOptions[locale]}
              className={styles.compactSelect}
              disabled={purchasesIsFetching && purchaseItems.length === 0}
            />
            <label className={styles.filterField}>
              <span>{text.searchFilterLabel}</span>
              <input
                className={styles.input}
                disabled={purchasesIsFetching && purchaseItems.length === 0}
                value={purchaseSearch}
                onChange={(event) =>
                  setPurchaseSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))
                }
                maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
                placeholder={text.purchaseSearchPlaceholder}
              />
            </label>
          </AdminFilterBar>
        </div>
        {purchasesIsFetching && purchaseItems.length === 0 ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : (
          <TableOrEmpty hasItems={purchaseItems.length > 0} emptyTitle={text.noPurchases}>
            {showPurchaseDetails ? (
              <div id="economy-purchase-details">
                <div
                  className={`${adminTableStyles.tableWrap} ${styles.entityTableWrap}`}
                  aria-busy={purchasesIsFetching}
                >
                  <table
                    className={`${adminTableStyles.table} ${styles.wideTable} ${styles.entityTable}`}
                  >
                    <thead>
                      <tr>
                        <th scope="col">{text.timeColumn}</th>
                        <th scope="col">{text.userColumn}</th>
                        <th scope="col">{text.productTypeColumn}</th>
                        <th scope="col">{text.packColumn}</th>
                        <th scope="col">{text.providerColumn}</th>
                        <th scope="col">{text.amountColumn}</th>
                        <th scope="col">{text.statusColumn}</th>
                        <th scope="col">{text.refundStatusColumn}</th>
                        <th scope="col">{text.actionsColumn}</th>
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
                            <td data-label={text.timeColumn}>
                              {formatDateTime(item.confirmedAtUtc ?? item.createdAtUtc, locale)}
                            </td>
                            <td className={adminTableStyles.mono} data-label={text.userColumn}>
                              {shortGuid(item.userId)}
                            </td>
                            <td data-label={text.productTypeColumn}>
                              {safeText(item.productType ?? "TokenPack")}
                            </td>
                            <td data-label={text.packColumn}>
                              <div className={styles.packMeta}>
                                <strong>{safeText(item.packDisplayName)}</strong>
                                <span>
                                  {item.tokenAmount ?? item.sparkToGrant} {text.tokensShort}
                                </span>
                              </div>
                            </td>
                            <td data-label={text.providerColumn}>
                              {humanizeProvider(item.paymentProvider, locale)}
                            </td>
                            <td data-label={text.amountColumn}>
                              {formatCurrency(item.priceAmount, locale, item.currencyCode)}
                            </td>
                            <td data-label={text.statusColumn}>
                              <AdminStatusBadge color={statusColor(item.status)}>
                                {humanizeStatus(item.status, locale)}
                              </AdminStatusBadge>
                            </td>
                            <td data-label={text.refundStatusColumn}>
                              {safeText(
                                item.refundStatus ??
                                  (item.status === "refunded" ? "refunded" : "none")
                              )}
                            </td>
                            <td data-label={text.actionsColumn}>
                              <div className={styles.tableActions}>
                                <Button
                                  type="button"
                                  size="sm"
                                  variant="ghost"
                                  aria-label={`${text.viewIncidentAction}: ${shortGuid(item.orderId)}`}
                                  onClick={() => onInspectPurchase(item)}
                                >
                                  {text.viewIncidentAction}
                                </Button>
                                {canRefund ? (
                                  <Button
                                    type="button"
                                    size="sm"
                                    variant="danger"
                                    disabled={isRefundPurchaseSubmitting}
                                    aria-label={`${text.refundPurchaseAction}: ${shortGuid(item.orderId)}`}
                                    onClick={() => onRefundPurchase(item)}
                                  >
                                    {text.refundPurchaseAction}
                                  </Button>
                                ) : null}
                              </div>
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
              </div>
            ) : (
              <ol className={styles.overviewPurchaseList} aria-busy={purchasesIsFetching}>
                {purchaseItems.slice(0, RECENT_ITEMS_LIMIT).map((item) => {
                  const canRefund =
                    item.canRefund === true &&
                    item.status !== "refunded" &&
                    item.status !== "failed";

                  return (
                    <li key={item.orderId} className={styles.overviewPurchaseItem}>
                      <div className={styles.overviewPurchaseCopy}>
                        <strong title={safeText(item.packDisplayName, 160)}>
                          {safeText(item.packDisplayName)}
                        </strong>
                        <span>
                          {humanizeProvider(item.paymentProvider, locale)} ·{" "}
                          {formatCompactDateTime(item.confirmedAtUtc ?? item.createdAtUtc, locale)}
                        </span>
                      </div>
                      <div className={styles.overviewPurchaseValue}>
                        <strong>
                          {formatCurrency(item.priceAmount, locale, item.currencyCode)}
                        </strong>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {humanizeStatus(item.status, locale)}
                        </AdminStatusBadge>
                      </div>
                      {canRefund ? (
                        <Button
                          type="button"
                          size="sm"
                          variant="danger"
                          disabled={isRefundPurchaseSubmitting}
                          aria-label={`${text.refundPurchaseAction}: ${shortGuid(item.orderId)}`}
                          onClick={() => onRefundPurchase(item)}
                        >
                          {text.refundPurchaseAction}
                        </Button>
                      ) : null}
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        aria-label={`${text.viewIncidentAction}: ${shortGuid(item.orderId)}`}
                        onClick={() => onInspectPurchase(item)}
                      >
                        {text.viewIncidentAction}
                      </Button>
                    </li>
                  );
                })}
              </ol>
            )}
          </TableOrEmpty>
        )}
      </AdminDataSurface>
    </div>
  );
}
