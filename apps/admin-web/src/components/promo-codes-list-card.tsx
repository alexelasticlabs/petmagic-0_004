"use client";

import { useEffect, useMemo, useState } from "react";

import {
  CaretDownIcon,
  DownloadIcon,
  MoreHorizontalIcon,
  RefreshIcon,
} from "@/components/admin/admin-icons";
import {
  AdminCard,
  AdminFilterBar,
  AdminStateCard,
  AdminStatusBadge,
  AdminToolbar,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  buildPromoCodesAutoRefreshLabel,
  buildPromoCodesPaginationSummary,
  buildPromoCodesPageLabel,
  type PromoCodesViewText,
} from "@/components/promo-codes-view.content";
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

const PROMO_CODES_SEARCH_MAX_LENGTH = 120;

const rewardKindColors: Record<AdminRedeemRewardKind, string> = {
  spark: "var(--success)",
  premium_days: "var(--info)",
};

type PromoCodesListCardProps = {
  text: ReturnType<typeof getDictionary>;
  promoText: PromoCodesViewText;
  locale: Locale;
  nowMs: number;
  search: string;
  statusFilter: PromoStatusFilter;
  rewardFilter: "all" | AdminRedeemRewardKind;
  sortMode: PromoSortMode;
  statusTabs: Array<{ value: PromoStatusFilter; label: string }>;
  statusOptions: SelectOption[];
  rewardOptions: SelectOption[];
  sortOptions: SelectOption[];
  pageSizeOptions: SelectOption[];
  hasCodes: boolean;
  hasFilteredCodes: boolean;
  canManagePromoCodes: boolean;
  promoCodesActionLocked: boolean;
  promoCodesQueryIsFetching: boolean;
  promoCodesQueryIsRefreshing: boolean;
  autoRefreshMs: number;
  dataUpdatedAt: number;
  pagedCodes: AdminRedeemCode[];
  selectedCodeId: string | null;
  actionsMenuCodeId: string | null;
  busyCodeId: string | null;
  currentPage: number;
  totalPages: number;
  totalCount: number;
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
  promoText,
  locale,
  nowMs,
  search,
  statusFilter,
  rewardFilter,
  sortMode,
  statusTabs,
  statusOptions,
  rewardOptions,
  sortOptions,
  pageSizeOptions,
  hasCodes,
  hasFilteredCodes,
  canManagePromoCodes,
  promoCodesActionLocked,
  promoCodesQueryIsFetching,
  promoCodesQueryIsRefreshing,
  autoRefreshMs,
  dataUpdatedAt,
  pagedCodes,
  selectedCodeId,
  actionsMenuCodeId,
  busyCodeId,
  currentPage,
  totalPages,
  totalCount,
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
            const isStatusTabDisabled = isActiveTab || promoCodesQueryIsFetching;

            return (
              <button
                key={tab.value}
                type="button"
                role="tab"
                aria-selected={isActiveTab}
                className={`${styles.statusTab}${isActiveTab ? ` ${styles.statusTabActive}` : ""}`}
                disabled={isStatusTabDisabled}
                onClick={() => onStatusTabChange(tab.value)}
                onKeyDown={(event) => {
                  if (isStatusTabDisabled) {
                    return;
                  }

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
              </button>
            );
          })}
        </div>

        <div className={styles.toolbarActions} data-testid="promo-codes-toolbar-actions">
          <Button
            variant="secondary"
            onClick={onExport}
            disabled={!hasFilteredCodes || !canManagePromoCodes || promoCodesQueryIsFetching}
          >
            <DownloadIcon className={styles.actionIcon} /> {text.promoCodesExportAction}
          </Button>
          <Button
            variant="secondary"
            onClick={onRefresh}
            disabled={!canManagePromoCodes || promoCodesQueryIsFetching}
          >
            <RefreshIcon className={styles.actionIcon} /> {text.promoCodesRefreshAction}
          </Button>
          <Button
            variant="primary"
            onClick={onOpenCreatePanel}
            disabled={!canManagePromoCodes || promoCodesActionLocked}
          >
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
            disabled={promoCodesQueryIsFetching}
            value={search}
            onChange={(event) =>
              onSearchChange(event.target.value.slice(0, PROMO_CODES_SEARCH_MAX_LENGTH))
            }
            maxLength={PROMO_CODES_SEARCH_MAX_LENGTH}
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
            disabled={promoCodesQueryIsFetching}
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
            disabled={promoCodesQueryIsFetching}
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
            disabled={promoCodesQueryIsFetching}
          />
        </div>
      </AdminFilterBar>

      {promoCodesQueryIsRefreshing ? (
        <AdminStateCard
          tone="info"
          title={text.navPromoCodes}
          description={text.promoCodesLoadingDescription}
        />
      ) : !hasCodes ? (
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
            <Button
              variant="secondary"
              size="sm"
              onClick={onResetFilters}
              disabled={promoCodesQueryIsFetching}
            >
              {text.resetForm}
            </Button>
          }
        />
      ) : (
        <>
          <div className={`${adminTableStyles.tableWrap} ${styles.promoTableWrap}`}>
            <table className={`${adminTableStyles.table} ${styles.promoTable}`}>
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
                  const actionsMenuLabel = `${text.promoCodesActionsMenuLabel}: ${codeValue}`;
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
                      <td data-label={text.promoCodesCodeLabel}>
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
                      <td data-label={text.promoCodesRewardLabel}>
                        <div className={styles.rewardCell}>
                          <AdminStatusBadge color={rewardKindColors[code.rewardKind]}>
                            {formatRewardValue(code.rewardValue, code.rewardKind, text)}
                          </AdminStatusBadge>
                          <span className={styles.descriptionMeta}>
                            {getRewardKindLabel(code.rewardKind, text)}
                          </span>
                        </div>
                      </td>
                      <td data-label={text.promoCodesUsageLabel}>
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
                      <td data-label={text.promoCodesPerUserLimitLabel}>
                        <span className={styles.inlineNumeric}>
                          {formatNumber(code.maxRedemptionsPerUser, locale)}
                        </span>
                      </td>
                      <td className={styles.windowCell} data-label={text.promoCodesWindowLabel}>
                        {formatWindow(code, locale, text)}
                      </td>
                      <td data-label={text.statusLabel}>
                        <AdminStatusBadge color={statusView.color}>
                          {statusView.label}
                        </AdminStatusBadge>
                      </td>
                      <td data-label={text.createdAtLabel}>
                        <div className={styles.createdCell}>
                          <strong>{formatDateTime(code.createdAtUtc, locale)}</strong>
                          <span>{formatPromoDisplayText(code.createdBy, 80)}</span>
                        </div>
                      </td>
                      <td data-label={text.actionsLabel}>
                        <div
                          className={styles.actionsMenu}
                          data-promo-actions-root
                          onClick={(event) => event.stopPropagation()}
                        >
                          <Button
                            variant="ghost"
                            size="sm"
                            className={styles.actionMenuTrigger}
                            aria-label={actionsMenuLabel}
                            aria-haspopup="menu"
                            aria-expanded={actionsMenuCodeId === code.redeemCodeId}
                            title={actionsMenuLabel}
                            onClick={(event) =>
                              onToggleActionsMenu(code.redeemCodeId, event.currentTarget)
                            }
                            disabled={actionBusy || promoCodesQueryIsFetching}
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
              {buildPromoCodesPaginationSummary(
                locale,
                formatNumber(shownRangeStart, locale),
                formatNumber(shownRangeEnd, locale),
                formatNumber(totalCount, locale)
              )}
            </span>
            <div className={styles.paginationCenter}>
              <Button
                variant="secondary"
                size="sm"
                onClick={onPreviousPage}
                disabled={currentPage <= 1 || promoCodesQueryIsFetching}
                aria-label={text.promoCodesPreviousAction}
                title={text.promoCodesPreviousAction}
              >
                <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
              </Button>

              <div className={styles.paginationActions}>
                {visiblePageNumbers.map((pageNumber) => (
                  <Button
                    key={pageNumber}
                    variant={pageNumber === currentPage ? "primary" : "secondary"}
                    size="sm"
                    className={styles.paginationNumber}
                    aria-current={pageNumber === currentPage ? "page" : undefined}
                    aria-label={buildPromoCodesPageLabel(locale, formatNumber(pageNumber, locale))}
                    onClick={() => onSelectPage(pageNumber)}
                    disabled={promoCodesQueryIsFetching}
                  >
                    {formatNumber(pageNumber, locale)}
                  </Button>
                ))}
              </div>

              <Button
                variant="secondary"
                size="sm"
                onClick={onNextPage}
                disabled={currentPage >= totalPages || promoCodesQueryIsFetching}
                aria-label={text.promoCodesNextAction}
                title={text.promoCodesNextAction}
              >
                <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
              </Button>
            </div>

            <div className={styles.pageSizeControl}>
              <Select
                value={pageSize.toString()}
                options={pageSizeOptions}
                onChange={(value) => onPageSizeChange(Number(value))}
                ariaLabel={promoText.pageSizeAriaLabel}
                showSelectedDescription={false}
                disabled={promoCodesQueryIsFetching}
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
    let timerId: number | null = null;

    const stopTimer = () => {
      if (timerId === null) {
        return;
      }

      window.clearInterval(timerId);
      timerId = null;
    };

    const startTimer = () => {
      if (document.visibilityState === "hidden" || timerId !== null) {
        return;
      }

      setNowTick(Date.now());
      timerId = window.setInterval(() => {
        setNowTick(Date.now());
      }, 1000);
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === "hidden") {
        stopTimer();
        return;
      }

      startTimer();
    };

    startTimer();
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      stopTimer();
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
        : buildPromoCodesAutoRefreshLabel(locale, secondsUntilAutoRefresh)}
    </span>
  );
}
