"use client";

import { Button } from "@/components/ui/button";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import { getUserRoleLabel } from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type {
  ActivityFilter,
  PremiumFilter,
  RangeDays,
  RoleFilter,
  StatusFilter,
} from "@/components/users-management-page.types";
import {
  USER_SEARCH_MAX_LENGTH,
} from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";

type UsersManagementUsersFiltersProps = {
  activityFilter: ActivityFilter;
  premiumFilter: PremiumFilter;
  rangeDays: RangeDays;
  resetAllFilters: () => void;
  resetUsersSelection: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setActivityFilter: (value: ActivityFilter) => void;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRangeDays: (value: RangeDays) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setStatusFilter: (value: StatusFilter) => void;
  statusFilter: StatusFilter;
  text: Dictionary;
  ui: UsersManagementPageText;
};

export function UsersManagementUsersFilters({
  activityFilter,
  premiumFilter,
  rangeDays,
  resetAllFilters,
  resetUsersSelection,
  roleFilter,
  search,
  setActivityFilter,
  setPremiumFilter,
  setRangeDays,
  setRoleFilter,
  setSearch,
  setStatusFilter,
  statusFilter,
  text,
  ui,
}: UsersManagementUsersFiltersProps) {
  return (
    <div className={styles.filtersBar}>
      <input
        className={styles.searchInput}
        placeholder={ui.searchPlaceholder}
        value={search}
        onChange={(event) => {
          setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));
          resetUsersSelection();
        }}
        maxLength={USER_SEARCH_MAX_LENGTH}
      />

      <select
        className={styles.filterSelect}
        value={roleFilter}
        onChange={(event) => {
          setRoleFilter(event.target.value as RoleFilter);
          resetUsersSelection();
        }}
        aria-label={ui.filterRole}
      >
        <option value="all">
          {ui.filterRole}: {ui.any}
        </option>
        <option value="User">{getUserRoleLabel("User", text)}</option>
        <option value="Moderator">{getUserRoleLabel("Moderator", text)}</option>
        <option value="Admin">{getUserRoleLabel("Admin", text)}</option>
      </select>

      <select
        className={styles.filterSelect}
        value={premiumFilter}
        onChange={(event) => {
          setPremiumFilter(event.target.value as PremiumFilter);
          resetUsersSelection();
        }}
        aria-label={ui.filterPremium}
      >
        <option value="all">
          {ui.filterPremium}: {ui.any}
        </option>
        <option value="premium">{ui.premiumOnly}</option>
        <option value="free">{ui.freeOnly}</option>
      </select>

      <select
        className={styles.filterSelect}
        value={activityFilter}
        onChange={(event) => {
          setActivityFilter(event.target.value as ActivityFilter);
          resetUsersSelection();
        }}
        aria-label={ui.filterActivity}
      >
        <option value="all">
          {ui.filterActivity}: {ui.any}
        </option>
        <option value="active">{ui.activeOnly}</option>
        <option value="blocked">{ui.blockedOnly}</option>
      </select>

      <select
        className={styles.filterSelect}
        value={statusFilter}
        onChange={(event) => {
          setStatusFilter(event.target.value as StatusFilter);
          resetUsersSelection();
        }}
        aria-label={ui.filterStatus}
      >
        <option value="all">
          {ui.filterStatus}: {ui.any}
        </option>
        <option value="active">{ui.statusActive}</option>
        <option value="blocked">{ui.statusBlocked}</option>
        <option value="unconfirmed">{ui.statusUnconfirmed}</option>
      </select>

      <select
        className={styles.filterSelect}
        value={String(rangeDays)}
        onChange={(event) => {
          setRangeDays(Number.parseInt(event.target.value, 10) as RangeDays);
          resetUsersSelection();
        }}
        aria-label={ui.periodLabel}
      >
        <option value="7">{ui.period7}</option>
        <option value="30">{ui.period30}</option>
        <option value="90">{ui.period90}</option>
      </select>

      <Button variant="ghost" size="sm" onClick={resetAllFilters}>
        {ui.resetFilters}
      </Button>
    </div>
  );
}
