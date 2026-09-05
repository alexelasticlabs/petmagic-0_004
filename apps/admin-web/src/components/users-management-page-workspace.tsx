"use client";

import { UsersManagementSummaryGrid } from "@/components/users-management-page.chrome";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import type {
  PremiumFilter,
  RangeDays,
  RoleFilter,
  StatusFilter,
  UserSortMode,
} from "@/components/users-management-page.types";
import { UsersManagementUsersCard } from "@/components/users-management-users-card";
import { useAuthSession, type UserListItem } from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

type UsersManagementPageWorkspaceProps = {
  activeUsersValue: string;
  blockedUsersValue: string;
  currentPage: number;
  error: string | null;
  isMetricsError: boolean;
  isMetricsFetching: boolean;
  isUsersFetching: boolean;
  isUsersRefreshing: boolean;
  locale: Locale;
  newUsersValue: string;
  premiumFilter: PremiumFilter;
  premiumUsersValue: string;
  refreshMetrics: () => Promise<void>;
  rangeDays: RangeDays;
  refreshUsers: () => Promise<void>;
  resetAllFilters: () => void;
  resetUsersPage: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRangeDays: (value: RangeDays) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setSortMode: (value: UserSortMode) => void;
  setStatusFilter: (value: StatusFilter) => void;
  sortMode: UserSortMode;
  statusFilter: StatusFilter;
  text: Dictionary;
  totalPages: number;
  totalUsersValue: string;
  ui: UsersManagementPageText;
  users: UserListItem[];
  usersPageTotalCount: number;
};

export function UsersManagementPageWorkspace({
  activeUsersValue,
  blockedUsersValue,
  currentPage,
  error,
  isMetricsError,
  isMetricsFetching,
  isUsersFetching,
  isUsersRefreshing,
  locale,
  newUsersValue,
  premiumFilter,
  premiumUsersValue,
  refreshMetrics,
  rangeDays,
  refreshUsers,
  resetAllFilters,
  resetUsersPage,
  roleFilter,
  search,
  setPremiumFilter,
  setRangeDays,
  setRoleFilter,
  setSearch,
  setSortMode,
  setStatusFilter,
  sortMode,
  statusFilter,
  text,
  totalPages,
  totalUsersValue,
  ui,
  users,
  usersPageTotalCount,
}: UsersManagementPageWorkspaceProps) {
  const session = useAuthSession();

  return (
    <>
      <UsersManagementSummaryGrid
        activeUsersValue={activeUsersValue}
        blockedUsersValue={blockedUsersValue}
        isMetricsError={isMetricsError}
        isMetricsFetching={isMetricsFetching}
        newUsersValue={newUsersValue}
        premiumUsersValue={premiumUsersValue}
        refreshMetrics={refreshMetrics}
        rangeDays={rangeDays}
        setRangeDays={setRangeDays}
        totalUsersValue={totalUsersValue}
        ui={ui}
      />

      <UsersManagementUsersCard
        key={session?.user.userId ?? "anonymous"}
        currentPage={currentPage}
        error={error}
        isUsersFetching={isUsersFetching}
        isUsersRefreshing={isUsersRefreshing}
        locale={locale}
        premiumFilter={premiumFilter}
        refreshUsers={refreshUsers}
        resetAllFilters={resetAllFilters}
        resetUsersPage={resetUsersPage}
        roleFilter={roleFilter}
        search={search}
        setPremiumFilter={setPremiumFilter}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setSortMode={setSortMode}
        setStatusFilter={setStatusFilter}
        sortMode={sortMode}
        statusFilter={statusFilter}
        text={text}
        totalPages={totalPages}
        ui={ui}
        users={users}
        usersPageTotalCount={usersPageTotalCount}
      />
    </>
  );
}
