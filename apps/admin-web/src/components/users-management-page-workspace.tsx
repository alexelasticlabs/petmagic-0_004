"use client";


import { UsersManagementSummaryGrid } from "@/components/users-management-page.chrome";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import type { ActivityFilter, PremiumFilter, RangeDays, RoleFilter, StatusFilter } from "@/components/users-management-page.types";
import { UsersManagementUsersCard } from "@/components/users-management-users-card";
import type {
  AdminEconomyUserSubscriptionSummary,
  AdminUserAnalytics,
  UserListItem,
} from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

import type { MutableRefObject } from "react";

type UsersManagementPageWorkspaceProps = {
  activeUsersValue: string;
  activityFilter: ActivityFilter;
  analyticsByUserId: Map<string, AdminUserAnalytics>;
  blockedUsersValue: string;
  busyUserId: string | null;
  canManageRoles: boolean;
  closeActionsMenu: () => void;
  currentPage: number;
  error: string | null;
  handleToggleActionsMenu: (userId: string) => void;
  isUserActionLocked: boolean;
  isUsersFetching: boolean;
  isUsersRefreshing: boolean;
  locale: Locale;
  newUsersValue: string;
  openActionsUserId: string | null;
  openSupportUserCount: number;
  openWalletDialog: (userId: string, operation: "credit" | "debit") => void;
  pageSubscriptionsByUserId: Map<string, AdminEconomyUserSubscriptionSummary>;
  pageUsers: UserListItem[];
  pagedUsers: UserListItem[];
  premiumFilter: PremiumFilter;
  premiumUsersValue: string;
  rangeDays: RangeDays;
  refreshUsers: () => Promise<void>;
  requestActiveChange: (user: UserListItem) => void;
  requestPremiumChange: (user: UserListItem) => void;
  resetAllFilters: () => void;
  resetUsersSelection: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setActivityFilter: (value: ActivityFilter) => void;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRangeDays: (value: RangeDays) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setSelectedUserId: (userId: string) => void;
  setStatusFilter: (value: StatusFilter) => void;
  statusFilter: StatusFilter;
  text: Dictionary;
  totalPages: number;
  totalUsersValue: string;
  triggerRefs: MutableRefObject<Record<string, HTMLButtonElement | null>>;
  ui: UsersManagementPageText;
  usersPageTotalCount: number;
};

export function UsersManagementPageWorkspace({
  activeUsersValue,
  activityFilter,
  analyticsByUserId,
  blockedUsersValue,
  busyUserId,
  canManageRoles,
  closeActionsMenu,
  currentPage,
  error,
  handleToggleActionsMenu,
  isUserActionLocked,
  isUsersFetching,
  isUsersRefreshing,
  locale,
  newUsersValue,
  openActionsUserId,
  openSupportUserCount,
  openWalletDialog,
  pageSubscriptionsByUserId,
  pageUsers,
  pagedUsers,
  premiumFilter,
  premiumUsersValue,
  rangeDays,
  refreshUsers,
  requestActiveChange,
  requestPremiumChange,
  resetAllFilters,
  resetUsersSelection,
  roleFilter,
  search,
  setActivityFilter,
  setPremiumFilter,
  setRangeDays,
  setRoleFilter,
  setSearch,
  setSelectedUserId,
  setStatusFilter,
  statusFilter,
  text,
  totalPages,
  totalUsersValue,
  triggerRefs,
  ui,
  usersPageTotalCount,
}: UsersManagementPageWorkspaceProps) {
  return (
    <>
      <UsersManagementSummaryGrid
        activeUsersValue={activeUsersValue}
        blockedUsersValue={blockedUsersValue}
        newUsersValue={newUsersValue}
        openSupportUserCount={openSupportUserCount}
        premiumUsersValue={premiumUsersValue}
        rangeDays={rangeDays}
        totalUsersValue={totalUsersValue}
        ui={ui}
      />

      <UsersManagementUsersCard
        activityFilter={activityFilter}
        analyticsByUserId={analyticsByUserId}
        busyUserId={busyUserId}
        canManageRoles={canManageRoles}
        closeActionsMenu={closeActionsMenu}
        currentPage={currentPage}
        error={error}
        handleToggleActionsMenu={handleToggleActionsMenu}
        isUserActionLocked={isUserActionLocked}
        isUsersFetching={isUsersFetching}
        isUsersRefreshing={isUsersRefreshing}
        locale={locale}
        openActionsUserId={openActionsUserId}
        openWalletDialog={openWalletDialog}
        pageSubscriptionsByUserId={pageSubscriptionsByUserId}
        pageUsers={pageUsers}
        pagedUsers={pagedUsers}
        premiumFilter={premiumFilter}
        rangeDays={rangeDays}
        refreshUsers={refreshUsers}
        requestActiveChange={requestActiveChange}
        requestPremiumChange={requestPremiumChange}
        resetAllFilters={resetAllFilters}
        resetUsersSelection={resetUsersSelection}
        roleFilter={roleFilter}
        search={search}
        setActivityFilter={setActivityFilter}
        setPremiumFilter={setPremiumFilter}
        setRangeDays={setRangeDays}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setSelectedUserId={setSelectedUserId}
        setStatusFilter={setStatusFilter}
        statusFilter={statusFilter}
        text={text}
        totalPages={totalPages}
        triggerRefs={triggerRefs}
        ui={ui}
        usersPageTotalCount={usersPageTotalCount}
      />
    </>
  );
}
