"use client";

import { useEffect, useMemo, useState } from "react";

import { DownloadIcon, MoreHorizontalIcon, RefreshIcon } from "@/components/admin/admin-icons";
import {
  AdminCard,
  AdminFilterBar,
  AdminStateCard,
  AdminStatusBadge,
  AdminToolbar,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  formatCampaignMeta,
  formatDateTime,
  formatNumber,
  formatPromoDisplayText,
  formatRewardValue,
  formatWindow,
  getPromoStatus,
  getRewardKindLabel,
  type PromoSortMode,
  type PromoStatusFilter,
} from "@/components/promo-codes-view.helpers";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { type AdminRedeemCode, type AdminRedeemRewardKind } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type PromoCodesListCardProps = {
  text: ReturnType<typeof getDictionary>;
  locale: Locale;
  nowMs: number;
  search: string;
  statusFilter: PromoStatusFilter;
  rewardFilter: "all" | AdminRedeemRewardKind;
  sortMode: PromoSortMode;
  statusTabs: Array<{ value: PromoStatusFilter; label: string }>;
  statusCounts: Record<PromoStatusFilter, number>;
  statusOptions: SelectOption[];
  rewardOptions: SelectOption[];
  sortOptions: SelectOption[];
  pageSizeOptions: SelectOption[];
  hasCodes: boolean;
  hasFilteredCodes: boolean;
  canManagePromoCodes: boolean;
  promoCodesQueryIsFetching: boolean;
  autoRefreshMs: number;
  dataUpdatedAt: number;
  pagedCodes: AdminRedeemCode[];
  filteredCodesCount: number;
  selectedCodeId: string | null;
  actionsMenuCodeId: string | null;
  busyCodeId: string | null;
  currentPage: number;
  totalPages: number;
  visiblePageNumbers: number[];
  shownRangeStart: number;
  shownRangeEnd: number;
  pageSize: number;
  onStatusTabChange: (value: PromoStatusFilter) => void;
  onSearchChange: (value: string) => void;
  onStatusFilterChange: (value: PromoStatusFilter) => void;
  onRewardFilterChange: (value: "all" | AdminRedeemRewardKind) => void;
  onSortModeChange: (value: PromoSortMode) => void;
  onPageSizeChange: (value: number) => void;
  onResetFilters: () => void;
  onExport: () => void;
  onRefresh: () => void;
  onOpenCreatePanel: () => void;
  onFocusUsage: (code: AdminRedeemCode) => void;
  onToggleActionsMenu: (redeemCodeId: string, anchor: HTMLButtonElement) => void;
  onPreviousPage: () => void;
  onNextPage: () => void;
  onSelectPage: (page: number) => void;
};

export function PromoCodesListCard({
  text,
  locale,
  nowMs,
  search,
  statusFilter,
  rewardFilter,
  sortMode,
  statusTabs,
  statusCounts,
  statusOptions,
  rewardOptions,
  sortOptions,
  pageSizeOptions,
  hasCodes,
  hasFilteredCodes,
  canManagePromoCodes,
  promoCodesQueryIsFetching,
  autoRefreshMs,
  dataUpdatedAt,
  pagedCodes,
  filteredCodesCount,
  selectedCodeId,
  actionsMenuCodeId,
  busyCodeId,
  currentPage,
  totalPages,
  visiblePageNumbers,
  shownRangeStart,
  shownRangeEnd,
  pageSize,
  onStatusTabChange,
  onSearchChange,
  onStatusFilterChange,
  onRewardFilterChange,
  onSortModeChange,
  onPageSizeChange,
  onResetFilters,
  onExport,
  onRefresh,
  onOpenCreatePanel,
  onFocusUsage,
  onToggleActionsMenu,
  onPreviousPage,
  onNextPage,
  onSelectPage,
}: PromoCodesListCardProps) {
  return (
    <AdminCard className={styles.tableCard}>
      <AdminToolbar className={styles.tableTopBar}>
        <div
          className={styles.statusTabs}
          role="tablist"
          aria-label={text.promoCodesStatusFilterLabel}
        >
          {statusTabs.map((tab, index) => {
            const isActiveTab = statusFilter === tab.value;

            return (
              <button
                key={tab.value}
                type="button"
                role="tab"
                aria-selected={isActiveTab}
                className={`${styles.statusTab}${isActiveTab ? ` ${styles.statusTabActive}` : ""}`}
                onClick={() => onStatusTabChange(tab.value)}
                onKeyDown={(event) => {
                  if (
                    event.key !== "ArrowLeft" &&
                    event.key !== "ArrowRight" &&
                    event.key !== "Home" &&
                    event.key !== "End"
                  ) {
                    return;
                  }

                  event.preventDefault();

                  let nextIndex = index;
                  if (event.key === "ArrowRight") {
                    nextIndex = (index + 1) % statusTabs.length;
                  } else if (event.key === "ArrowLeft") {
                    nextIndex = (index - 1 + statusTabs.length) % statusTabs.length;
                  } else if (event.key === "Home") {
                    nextIndex = 0;
                  } else if (event.key === "End") {
                    nextIndex = statusTabs.length - 1;
                  }

                  onStatusTabChange(statusTabs[nextIndex].value);
                }}
              >
                <span>{tab.label}</span>
                <span className={styles.statusTabCount}>
                  {formatNumber(statusCounts[tab.value], locale)}
                </span>
              </button>
            );
          })}
        </div>

        <div className={styles.toolbarActions}>
          <Button
            variant="secondary"
            onClick={onExport}
            disabled={!hasFilteredCodes || !canManagePromoCodes}
          >
            <DownloadIcon className={styles.actionIcon} /> {text.promoCodesExportAction}
          </Button>
          <Button variant="secondary" onClick={onRefresh} disabled={promoCodesQueryIsFetching}>
            <RefreshIcon className={styles.actionIcon} /> {text.promoCodesRefreshAction}
          </Button>
          <Button variant="primary" onClick={onOpenCreatePanel} disabled={!canManagePromoCodes}>
            {text.promoCodesCreateAction}
          </Button>
          <PromoCodesAutoRefreshBadge
            text={text}
            locale={locale}
            isFetching={promoCodesQueryIsFetching}
            autoRefreshMs={autoRefreshMs}
            dataUpdatedAt={dataUpdatedAt}
          />
        </div>
      </AdminToolbar>

      <AdminFilterBar className={styles.filterBar}>
        <label className={styles.searchField}>
          <span className={styles.fieldLabel}>{text.promoCodesSearchPlaceholder}</span>
          <input
            className={styles.searchInput}
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder={text.promoCodesSearchPlaceholder}
          />
        </label>
        <div className={styles.selectField}>
          <span className={styles.fieldLabel}>{text.promoCodesStatusFilterLabel}</span>
          <Select
            value={statusFilter}
            options={statusOptions}
            onChange={(value) => onStatusFilterChange(value as PromoStatusFilter)}
            ariaLabel={text.promoCodesStatusFilterLabel}
            showSelectedDescription={false}
          />
        </div>
        <div className={styles.selectField}>
          <span className={styles.fieldLabel}>{text.promoCodesRewardTypeLabel}</span>
          <Select
            value={rewardFilter}
            options={rewardOptions}
            onChange={(value) => onRewardFilterChange(value as "all" | AdminRedeemRewardKind)}
            ariaLabel={text.promoCodesRewardTypeLabel}
            showSelectedDescription={false}
          />
        </div>
        <div className={styles.selectField}>
          <span className={styles.fieldLabel}>{text.promoCodesSortLabel}</span>
          <Select
            value={sortMode}
            options={sortOptions}
            onChange={(value) => onSortModeChange(value as PromoSortMode)}
            ariaLabel={text.promoCodesSortLabel}
            showSelectedDescription={false}
          />
        </div>
      </AdminFilterBar>

      {!hasCodes ? (
        <AdminStateCard
          tone="info"
          title={text.navPromoCodes}
          description={text.promoCodesEmptyDescription}
        />
      ) : !hasFilteredCodes ? (
        <AdminStateCard
          tone="neutral"
          title={text.navPromoCodes}
          description={text.promoCodesNoResults}
          action={
            <Button variant="secondary" size="sm" onClick={onResetFilters}>
              {text.resetForm}
            </Button>
          }
        />
      ) : (
        <>
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.promoCodesCodeLabel}</th>
                  <th>{text.promoCodesRewardLabel}</th>
                  <th>{text.promoCodesUsageLabel}</th>
                  <th>{text.promoCodesPerUserLimitLabel}</th>
                  <th>{text.promoCodesWindowLabel}</th>
                  <th>{text.statusLabel}</th>
                  <th>{text.createdAtLabel}</th>
                  <th>{text.actionsLabel}</th>
                </tr>
              </thead>
              <tbody>
                {pagedCodes.map((code) => {
                  const status = getPromoStatus(code, text, nowMs).key;
                  const statusView = getPromoStatus(code, text, nowMs);
                  const isSelected = selectedCodeId === code.redeemCodeId;
                  const codeValue = formatPromoDisplayText(
                    code.code || `${code.codePrefix}...`,
                    80
                  );
                  const actionBusy = busyCodeId === code.redeemCodeId;
                  const campaignMeta = formatCampaignMeta(code);
                  const usagePercent = Math.min(
                    100,
                    Math.round((code.redeemedCount / Math.max(1, code.maxRedemptions)) * 100)
                  );
                  const usageToneClass =
                    usagePercent >= 80
                      ? styles.usageToneCritical
                      : usagePercent >= 45
                        ? styles.usageToneMedium
                        : styles.usageToneGood;

                  return (
                    <tr
                      key={code.redeemCodeId}
                      className={`${styles.tableRow}${isSelected ? ` ${styles.rowSelected}` : ""}`}
                      onClick={() => onFocusUsage(code)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          onFocusUsage(code);
                        }
                      }}
                      tabIndex={0}
                      aria-selected={isSelected}
                      data-status={status}
                    >
                      <td>
                        <div className={styles.codeCell}>
                          <strong className={styles.codeValue}>{codeValue}</strong>
                          <span className={styles.codeMeta}>
                            {formatPromoDisplayText(code.description, 160)}
                          </span>
                          {campaignMeta ? (
                            <span className={styles.codeMeta}>{campaignMeta}</span>
                          ) : null}
                          <span className={styles.codeMeta}>
                            {text.promoCodesUpdatedLabel}:{" "}
                            {formatDateTime(code.updatedAtUtc, locale)}
                          </span>
                        </div>
                      </td>
                      <td>
                        <div className={styles.rewardCell}>
                          <AdminStatusBadge
                            color={code.rewardKind === "spark" ? "#22c55e" : "#60a5fa"}
                          >
                            {formatRewardValue(code.rewardValue, code.rewardKind, text)}
                          </AdminStatusBadge>
                          <span className={styles.descriptionMeta}>
                            {getRewardKindLabel(code.rewardKind, text)}
                          </span>
                        </div>
                      </td>
                      <td>
                        <div className={styles.usageCell}>
                          <div className={styles.usageTopRow}>
                            <strong>
                              {formatNumber(code.redeemedCount, locale)} /{" "}
                              {formatNumber(code.maxRedemptions, locale)}
                            </strong>
                            <span className={`${styles.usagePercent} ${usageToneClass}`}>
                              {usagePercent}%
                            </span>
                          </div>
                          <div className={`${styles.usageMeter} ${usageToneClass}`}>
                            <span style={{ width: `${usagePercent}%` }} />
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className={styles.inlineNumeric}>
                          {formatNumber(code.maxRedemptionsPerUser, locale)}
                        </span>
                      </td>
                      <td className={styles.windowCell}>{formatWindow(code, locale, text)}</td>
                      <td>
                        <AdminStatusBadge color={statusView.color}>
                          {statusView.label}
                        </AdminStatusBadge>
                      </td>
                      <td>
                        <div className={styles.createdCell}>
                          <strong>{formatDateTime(code.createdAtUtc, locale)}</strong>
                          <span>{formatPromoDisplayText(code.createdBy, 80)}</span>
                        </div>
                      </td>
                      <td>
                        <div
                          className={styles.actionsMenu}
                          data-promo-actions-root
                          onClick={(event) => event.stopPropagation()}
                        >
                          <Button
                            variant="ghost"
                            size="sm"
                            className={styles.actionMenuTrigger}
                            aria-label={text.promoCodesActionsMenuLabel}
                            aria-haspopup="menu"
                            aria-expanded={actionsMenuCodeId === code.redeemCodeId}
                            onClick={(event) =>
                              onToggleActionsMenu(code.redeemCodeId, event.currentTarget)
                            }
                            disabled={actionBusy}
                          >
                            <MoreHorizontalIcon className={styles.inlineIcon} />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className={styles.pagination}>
            <span className={styles.paginationInfo}>
              {locale === "ru"
                ? `Показано ${formatNumber(shownRangeStart, locale)}-${formatNumber(shownRangeEnd, locale)} из ${formatNumber(filteredCodesCount, locale)}`
                : `Showing ${formatNumber(shownRangeStart, locale)}-${formatNumber(shownRangeEnd, locale)} of ${formatNumber(filteredCodesCount, locale)}`}
            </span>
            <div className={styles.paginationCenter}>
              <Button
                variant="secondary"
                size="sm"
                onClick={onPreviousPage}
                disabled={currentPage <= 1}
                aria-label={text.promoCodesPreviousAction}
              >
                {"<"}
              </Button>

              <div className={styles.paginationActions}>
                {visiblePageNumbers.map((pageNumber) => (
                  <Button
                    key={pageNumber}
                    variant={pageNumber === currentPage ? "primary" : "secondary"}
                    size="sm"
                    className={styles.paginationNumber}
                    onClick={() => onSelectPage(pageNumber)}
                  >
                    {formatNumber(pageNumber, locale)}
                  </Button>
                ))}
              </div>

              <Button
                variant="secondary"
                size="sm"
                onClick={onNextPage}
                disabled={currentPage >= totalPages}
                aria-label={text.promoCodesNextAction}
              >
                {">"}
              </Button>
            </div>

            <div className={styles.pageSizeControl}>
              <Select
                value={pageSize.toString()}
                options={pageSizeOptions}
                onChange={(value) => onPageSizeChange(Number(value))}
                ariaLabel={locale === "ru" ? "Размер страницы" : "Page size"}
                showSelectedDescription={false}
              />
            </div>
          </div>
        </>
      )}
    </AdminCard>
  );
}

function PromoCodesAutoRefreshBadge({
  text,
  locale,
  isFetching,
  autoRefreshMs,
  dataUpdatedAt,
}: {
  text: ReturnType<typeof getDictionary>;
  locale: Locale;
  isFetching: boolean;
  autoRefreshMs: number;
  dataUpdatedAt: number;
}) {
  const [nowTick, setNowTick] = useState(() => Date.now());
  const secondsUntilAutoRefresh = useMemo(() => {
    if (!dataUpdatedAt) {
      return Math.ceil(autoRefreshMs / 1000);
    }

    const elapsed = Math.max(0, nowTick - dataUpdatedAt);
    const remaining = autoRefreshMs - (elapsed % autoRefreshMs);
    return Math.max(1, Math.ceil(remaining / 1000));
  }, [autoRefreshMs, dataUpdatedAt, nowTick]);

  useEffect(() => {
    const timerId = window.setInterval(() => {
      setNowTick(Date.now());
    }, 1000);

    return () => {
      window.clearInterval(timerId);
    };
  }, []);

  return (
    <span
      className={`${styles.autoRefreshBadge}${isFetching ? ` ${styles.autoRefreshBadgeLoading}` : ""}`}
      aria-live="polite"
    >
      <span className={styles.autoRefreshDot} />
      {isFetching
        ? text.promoCodesUpdatingLabel
        : locale === "ru"
          ? `Автообновление: ${secondsUntilAutoRefresh}с`
          : `Auto refresh: ${secondsUntilAutoRefresh}s`}
    </span>
  );
}
