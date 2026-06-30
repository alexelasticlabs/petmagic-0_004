"use client";

import { PromoCodeActivationsCard } from "@/components/promo-code-activations-card";
import { PromoCodesListCard } from "@/components/promo-codes-list-card";
import { type PromoCodesViewText } from "@/components/promo-codes-view.content";
import {
  type PromoSortMode,
  type PromoStatusFilter,
} from "@/components/promo-codes-view.helpers";
import { type SelectOption } from "@/components/ui/select";
import {
  type AdminRedeemCode,
  type AdminRedeemCodeRedemption,
  type AdminRedeemRewardKind,
  type AdminUserDetail,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type PromoCodesViewWorkspaceProps = {
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
  isMutating: boolean;
  isPromoRefreshFetching: boolean;
  isPromoCodesRefreshing: boolean;
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
  selectedCode: AdminRedeemCode | null;
  selectedStatusLabel?: string;
  activationsIsLoading: boolean;
  activationsIsError: boolean;
  activationsIsFetching: boolean;
  redemptionsForView: AdminRedeemCodeRedemption[];
  selectedUsersById: Map<string, AdminUserDetail>;
  hasAnyRedemptions: boolean;
  showAllActivations: boolean;
  canExpandActivations: boolean;
  canGoToPreviousActivationsPage: boolean;
  canGoToNextActivationsPage: boolean;
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
  onSelectPage: (nextPage?: number) => void;
  onRefetchActivations: () => Promise<unknown>;
  onShowAllActivations: () => void;
  onPreviousActivationsPage: () => void;
  onNextActivationsPage: () => void;
  onShowLatestActivations: () => void;
};

export function PromoCodesViewWorkspace(props: PromoCodesViewWorkspaceProps) {
  const {
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
    isMutating,
    isPromoRefreshFetching,
    isPromoCodesRefreshing,
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
    selectedCode,
    selectedStatusLabel,
    activationsIsLoading,
    activationsIsError,
    activationsIsFetching,
    redemptionsForView,
    selectedUsersById,
    hasAnyRedemptions,
    showAllActivations,
    canExpandActivations,
    canGoToPreviousActivationsPage,
    canGoToNextActivationsPage,
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
    onRefetchActivations,
    onShowAllActivations,
    onPreviousActivationsPage,
    onNextActivationsPage,
    onShowLatestActivations,
  } = props;

  return (
    <>
      <PromoCodesListCard
        text={text}
        promoText={promoText}
        locale={locale}
        nowMs={nowMs}
        search={search}
        statusFilter={statusFilter}
        rewardFilter={rewardFilter}
        sortMode={sortMode}
        statusTabs={statusTabs}
        statusOptions={statusOptions}
        rewardOptions={rewardOptions}
        sortOptions={sortOptions}
        pageSizeOptions={pageSizeOptions}
        hasCodes={hasCodes}
        hasFilteredCodes={hasFilteredCodes}
        canManagePromoCodes={canManagePromoCodes}
        promoCodesActionLocked={isMutating}
        promoCodesQueryIsFetching={isPromoRefreshFetching}
        promoCodesQueryIsRefreshing={isPromoCodesRefreshing}
        autoRefreshMs={15_000}
        dataUpdatedAt={dataUpdatedAt}
        pagedCodes={pagedCodes}
        selectedCodeId={selectedCodeId}
        actionsMenuCodeId={actionsMenuCodeId}
        busyCodeId={busyCodeId}
        currentPage={currentPage}
        totalPages={totalPages}
        totalCount={totalCount}
        visiblePageNumbers={visiblePageNumbers}
        shownRangeStart={shownRangeStart}
        shownRangeEnd={shownRangeEnd}
        pageSize={pageSize}
        onStatusTabChange={onStatusTabChange}
        onSearchChange={onSearchChange}
        onStatusFilterChange={onStatusFilterChange}
        onRewardFilterChange={onRewardFilterChange}
        onSortModeChange={onSortModeChange}
        onPageSizeChange={onPageSizeChange}
        onResetFilters={onResetFilters}
        onExport={onExport}
        onRefresh={onRefresh}
        onOpenCreatePanel={onOpenCreatePanel}
        onFocusUsage={onFocusUsage}
        onToggleActionsMenu={onToggleActionsMenu}
        onPreviousPage={onPreviousPage}
        onNextPage={onNextPage}
        onSelectPage={onSelectPage}
      />

      <PromoCodeActivationsCard
        text={text}
        locale={locale}
        selectedCode={selectedCode}
        selectedStatusLabel={selectedStatusLabel}
        activationsIsLoading={activationsIsLoading}
        activationsIsError={activationsIsError}
        activationsIsFetching={activationsIsFetching}
        redemptionsForView={redemptionsForView}
        selectedUsersById={selectedUsersById}
        hasAnyRedemptions={hasAnyRedemptions}
        showAllActivations={showAllActivations}
        canExpandActivations={canExpandActivations}
        canGoToPreviousActivationsPage={canGoToPreviousActivationsPage}
        canGoToNextActivationsPage={canGoToNextActivationsPage}
        onRefetchActivations={onRefetchActivations}
        onShowAllActivations={onShowAllActivations}
        onPreviousActivationsPage={onPreviousActivationsPage}
        onNextActivationsPage={onNextActivationsPage}
        onShowLatestActivations={onShowLatestActivations}
      />
    </>
  );
}
