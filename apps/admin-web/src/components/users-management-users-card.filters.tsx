"use client";

import { useState } from "react";

import { CancelCircleIcon, SearchIcon } from "@/components/admin/admin-icons";
import { AdminFilterBar } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import { getUserRoleLabel } from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type {
  PremiumFilter,
  RoleFilter,
  StatusFilter,
  UserSortMode,
} from "@/components/users-management-page.types";
import { USER_SEARCH_MAX_LENGTH } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";

type UsersManagementUsersFiltersProps = {
  premiumFilter: PremiumFilter;
  resetAllFilters: () => void;
  resetUsersPage: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setSortMode: (value: UserSortMode) => void;
  setStatusFilter: (value: StatusFilter) => void;
  sortMode: UserSortMode;
  statusFilter: StatusFilter;
  text: Dictionary;
  ui: UsersManagementPageText;
};

export function UsersManagementUsersFilters({
  premiumFilter,
  resetAllFilters,
  resetUsersPage,
  roleFilter,
  search,
  setPremiumFilter,
  setRoleFilter,
  setSearch,
  setSortMode,
  setStatusFilter,
  sortMode,
  statusFilter,
  text,
  ui,
}: UsersManagementUsersFiltersProps) {
  const [isFiltersExpanded, setIsFiltersExpanded] = useState(false);
  const roleOptions: readonly SelectOption[] = [
    { value: "all", label: ui.any },
    { value: "User", label: getUserRoleLabel("User", text) },
    { value: "Moderator", label: getUserRoleLabel("Moderator", text) },
    { value: "Admin", label: getUserRoleLabel("Admin", text) },
  ];
  const premiumOptions: readonly SelectOption[] = [
    { value: "all", label: ui.any },
    { value: "premium", label: ui.premiumOnly },
    { value: "free", label: ui.freeOnly },
  ];
  const statusOptions: readonly SelectOption[] = [
    { value: "all", label: ui.any },
    { value: "active", label: ui.statusActive },
    { value: "blocked", label: ui.statusBlocked },
    { value: "unconfirmed", label: ui.statusUnconfirmed },
  ];
  const sortOptions: readonly SelectOption[] = [
    { value: "created_desc", label: ui.sortCreatedDesc },
    { value: "created_asc", label: ui.sortCreatedAsc },
    { value: "last_activity_desc", label: ui.sortLastActivityDesc },
    { value: "last_activity_asc", label: ui.sortLastActivityAsc },
  ];
  const advancedFiltersCount = [
    roleFilter !== "all",
    premiumFilter !== "all",
    statusFilter !== "all",
  ].filter(Boolean).length;
  const activeFilters: Array<{
    id: "search" | "role" | "premium" | "status" | "sort";
    label: string;
    value: string;
    onClear: () => void;
  }> = [];
  const normalizedSearch = search.trim();

  if (normalizedSearch) {
    activeFilters.push({
      id: "search",
      label: ui.searchLabel,
      value: normalizedSearch,
      onClear: () => {
        setSearch("");
        resetUsersPage();
      },
    });
  }

  if (roleFilter !== "all") {
    activeFilters.push({
      id: "role",
      label: ui.filterRole,
      value: roleOptions.find((option) => option.value === roleFilter)?.label ?? roleFilter,
      onClear: () => {
        setRoleFilter("all");
        resetUsersPage();
      },
    });
  }
  if (premiumFilter !== "all") {
    activeFilters.push({
      id: "premium",
      label: ui.filterPremium,
      value:
        premiumOptions.find((option) => option.value === premiumFilter)?.label ?? premiumFilter,
      onClear: () => {
        setPremiumFilter("all");
        resetUsersPage();
      },
    });
  }
  if (statusFilter !== "all") {
    activeFilters.push({
      id: "status",
      label: ui.filterStatus,
      value: statusOptions.find((option) => option.value === statusFilter)?.label ?? statusFilter,
      onClear: () => {
        setStatusFilter("all");
        resetUsersPage();
      },
    });
  }
  if (sortMode !== "created_desc") {
    activeFilters.push({
      id: "sort",
      label: ui.sortLabel,
      value: sortOptions.find((option) => option.value === sortMode)?.label ?? sortMode,
      onClear: () => {
        setSortMode("created_desc");
        resetUsersPage();
      },
    });
  }

  const hasResettableControls = activeFilters.length > 0;
  const filtersButtonLabel = advancedFiltersCount
    ? ui.filtersWithCount.replace("{count}", String(advancedFiltersCount))
    : ui.filtersLabel;

  return (
    <AdminFilterBar className={styles.filtersBar}>
      <label className={styles.searchField}>
        <span className={styles.filterLabel}>{ui.searchLabel}</span>
        <span className={styles.searchControl}>
          <SearchIcon className={styles.searchIcon} />
          <input
            className={styles.searchInput}
            placeholder={ui.searchPlaceholder}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));
              resetUsersPage();
            }}
            maxLength={USER_SEARCH_MAX_LENGTH}
          />
          {search ? (
            <button
              type="button"
              className={styles.clearSearchButton}
              aria-label={ui.clearSearch}
              title={ui.clearSearch}
              onClick={() => {
                setSearch("");
                resetUsersPage();
              }}
            >
              <CancelCircleIcon />
            </button>
          ) : null}
        </span>
      </label>

      <div className={styles.selectField}>
        <span className={styles.filterLabel}>{ui.sortLabel}</span>
        <Select
          value={sortMode}
          options={sortOptions}
          onChange={(value) => {
            setSortMode(value as UserSortMode);
            resetUsersPage();
          }}
          ariaLabel={ui.sortLabel}
          showSelectedDescription={false}
        />
      </div>

      <div className={styles.filterActions}>
        <Button
          variant={advancedFiltersCount || isFiltersExpanded ? "secondary" : "ghost"}
          size="sm"
          aria-expanded={isFiltersExpanded}
          aria-controls="users-advanced-filters"
          onClick={() => setIsFiltersExpanded((current) => !current)}
        >
          {filtersButtonLabel}
        </Button>
        {hasResettableControls ? (
          <Button
            className={styles.resetFiltersButton}
            variant="ghost"
            size="sm"
            onClick={() => {
              resetAllFilters();
              setIsFiltersExpanded(false);
            }}
          >
            {ui.resetFilters}
          </Button>
        ) : null}
      </div>

      {isFiltersExpanded ? (
        <div id="users-advanced-filters" className={styles.advancedFilters}>
          <div className={styles.selectField}>
            <span className={styles.filterLabel}>{ui.filterRole}</span>
            <Select
              value={roleFilter}
              options={roleOptions}
              onChange={(value) => {
                setRoleFilter(value as RoleFilter);
                resetUsersPage();
              }}
              ariaLabel={ui.filterRole}
              showSelectedDescription={false}
            />
          </div>

          <div className={styles.selectField}>
            <span className={styles.filterLabel}>{ui.filterPremium}</span>
            <Select
              value={premiumFilter}
              options={premiumOptions}
              onChange={(value) => {
                setPremiumFilter(value as PremiumFilter);
                resetUsersPage();
              }}
              ariaLabel={ui.filterPremium}
              showSelectedDescription={false}
            />
          </div>

          <div className={styles.selectField}>
            <span className={styles.filterLabel}>{ui.filterStatus}</span>
            <Select
              value={statusFilter}
              options={statusOptions}
              onChange={(value) => {
                setStatusFilter(value as StatusFilter);
                resetUsersPage();
              }}
              ariaLabel={ui.filterStatus}
              showSelectedDescription={false}
            />
          </div>
        </div>
      ) : null}

      {activeFilters.length ? (
        <div className={styles.activeFilters} aria-label={ui.filtersLabel}>
          {activeFilters.map((filter) => (
            <button
              key={filter.id}
              type="button"
              className={styles.activeFilterChip}
              aria-label={`${ui.resetFilters}: ${filter.label} — ${filter.value}`}
              onClick={filter.onClear}
            >
              <span>
                {filter.label}: {filter.value}
              </span>
              <CancelCircleIcon />
            </button>
          ))}
        </div>
      ) : null}
    </AdminFilterBar>
  );
}
