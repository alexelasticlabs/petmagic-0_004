"use client";

import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { type ReactNode } from "react";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  CancelCircleIcon,
  CaretDownIcon,
  PeopleIcon,
  PlusIcon,
  SearchIcon,
} from "@/components/admin/admin-icons";
import { AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import {
  getRoleManagementPageText,
  type RoleManagementPageText,
} from "@/components/role-management-page.content";
import styles from "@/components/role-management-page.module.css";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignRole,
  fetchUsers,
  revokeRole,
  USER_SEARCH_MAX_LENGTH,
  useAuthSession,
  type UserListItem,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { type Locale } from "@/lib/i18n";
import {
  getAdminUserDisplayName,
  maskEmail,
  sanitizeSensitiveText,
  shortIdentifier,
} from "@/lib/sensitive-display";

type RoleManagementPageProps = {
  locale: Locale;
};

type PendingAction = {
  targetUserId: string;
  title: string;
  description: string;
  confirmLabel: string;
  tone: "danger" | "primary";
  action: () => Promise<void>;
};

const PAGE_SIZE = 50;
const SEARCH_PAGE_SIZE = 20;

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function userDisplayName(user: UserListItem) {
  return sanitizeSensitiveText(getAdminUserDisplayName(user), 96);
}

function getRoleActionErrorDetails(error: unknown, targetUserId: string) {
  return {
    targetUserId: shortIdentifier(targetUserId),
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getExistingManagedRole(user: UserListItem, text: RoleManagementPageText) {
  if (user.roles.includes("Admin")) {
    return text.adminRole;
  }

  if (user.roles.includes("Moderator")) {
    return text.moderatorRole;
  }

  return null;
}

function getUserInitials(user: UserListItem) {
  const initials = userDisplayName(user)
    .split(/\s+/)
    .map((part) => part.slice(0, 1))
    .filter(Boolean)
    .slice(0, 2)
    .join("");

  return initials.toUpperCase() || "U";
}

function UserRow({
  user,
  locale,
  text,
  action,
}: {
  user: UserListItem;
  locale: Locale;
  text: RoleManagementPageText;
  action?: ReactNode;
}) {
  return (
    <article className={styles.userRow}>
      <span className={styles.userAvatar} aria-hidden="true">
        {getUserInitials(user)}
      </span>
      <Link
        className={styles.userMain}
        href={`/${locale}/users/${encodeURIComponent(user.userId)}`}
        aria-label={`${text.openUserProfile}: ${userDisplayName(user)}`}
      >
        <span className={styles.userName}>{userDisplayName(user)}</span>
        <span className={styles.userMeta}>{maskEmail(user.email)}</span>
      </Link>
      {action ? <div className={styles.userAction}>{action}</div> : null}
    </article>
  );
}

function RolePager({
  text,
  label,
  pageIndex,
  pageSize,
  totalCount,
  hasMore,
  isFetching,
  onPrevious,
  onNext,
}: {
  text: RoleManagementPageText;
  label: string;
  pageIndex: number;
  pageSize: number;
  totalCount: number;
  hasMore: boolean;
  isFetching: boolean;
  onPrevious: () => void;
  onNext: () => void;
}) {
  if (pageIndex === 0 && !hasMore && totalCount <= pageSize) {
    return null;
  }

  const pageCount = Math.max(1, Math.ceil(totalCount / pageSize));
  return (
    <nav className={styles.pager} aria-label={label}>
      <span className={styles.pageInfo}>
        {text.page} {pageIndex + 1} {text.of} {pageCount}
      </span>
      <div className={styles.pagerActions}>
        <Button
          variant="ghost"
          size="sm"
          className={styles.pagerButton}
          disabled={pageIndex === 0 || isFetching}
          aria-label={text.previousPageLabel}
          title={text.previousPageLabel}
          onClick={onPrevious}
        >
          <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
        </Button>
        <Button
          variant="ghost"
          size="sm"
          className={styles.pagerButton}
          disabled={!hasMore || isFetching}
          aria-label={text.nextPageLabel}
          title={text.nextPageLabel}
          onClick={onNext}
        >
          <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
        </Button>
      </div>
    </nav>
  );
}

export function RoleManagementPage({ locale }: RoleManagementPageProps) {
  const text = getRoleManagementPageText(locale);
  const queryClient = useQueryClient();
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canManageRoles = sessionRoles.includes("Admin");
  const [search, setSearch] = useState("");
  const [searchPage, setSearchPage] = useState(0);
  const [adminsPage, setAdminsPage] = useState(0);
  const [moderatorsPage, setModeratorsPage] = useState(0);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const roleActionInFlightRef = useRef(false);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const debouncedSearch = useDebouncedValue(search, 350);
  const currentSearch = search.trim();
  const normalizedSearch = debouncedSearch.trim();
  const isSearchActive = currentSearch.length >= 2;
  const isSearchPending = isSearchActive && currentSearch !== normalizedSearch;

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timeoutId = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const adminQueryParams = useMemo(
    () => ({ role: "Admin", skip: adminsPage * PAGE_SIZE, take: PAGE_SIZE }),
    [adminsPage]
  );
  const moderatorQueryParams = useMemo(
    () => ({ role: "Moderator", skip: moderatorsPage * PAGE_SIZE, take: PAGE_SIZE }),
    [moderatorsPage]
  );

  const adminsQuery = useQuery({
    queryKey: adminQueryKeys.users(adminQueryParams),
    queryFn: ({ signal }) => fetchUsers(adminQueryParams, signal),
    enabled: canManageRoles,
    placeholderData: keepPreviousData,
  });

  const moderatorsQuery = useQuery({
    queryKey: adminQueryKeys.users(moderatorQueryParams),
    queryFn: ({ signal }) => fetchUsers(moderatorQueryParams, signal),
    enabled: canManageRoles,
    placeholderData: keepPreviousData,
  });

  const searchQueryParams = useMemo(
    () => ({
      search: normalizedSearch,
      skip: searchPage * SEARCH_PAGE_SIZE,
      take: SEARCH_PAGE_SIZE,
    }),
    [normalizedSearch, searchPage]
  );
  const searchQuery = useQuery({
    queryKey: adminQueryKeys.users(searchQueryParams),
    queryFn: ({ signal }) => fetchUsers(searchQueryParams, signal),
    enabled: canManageRoles && isSearchActive && !isSearchPending && normalizedSearch.length >= 2,
    placeholderData: keepPreviousData,
  });

  const isLoading = adminsQuery.isLoading || moderatorsQuery.isLoading;
  const isError = adminsQuery.isError || moderatorsQuery.isError;
  const isRoleRetryFetching = adminsQuery.isFetching || moderatorsQuery.isFetching;
  const isRoleActionDisabled = isSubmitting;

  function focusSearch() {
    if (!canManageRoles) {
      return;
    }

    searchInputRef.current?.scrollIntoView({ block: "center" });
    searchInputRef.current?.focus();
  }

  function setSearchContext(nextSearch: string) {
    resetPendingRoleAction();
    setSearchPage(0);
    setSearch(nextSearch.slice(0, USER_SEARCH_MAX_LENGTH));
  }

  function clearSearch() {
    setSearchContext("");
    window.requestAnimationFrame(focusSearch);
  }

  function requestRoleListsRetry() {
    if (!canManageRoles || isRoleRetryFetching) {
      return;
    }

    void Promise.allSettled([adminsQuery.refetch(), moderatorsQuery.refetch()]);
  }

  function requestAdminsRetry() {
    if (!canManageRoles || adminsQuery.isFetching) {
      return;
    }

    void adminsQuery.refetch().catch(() => undefined);
  }

  function requestModeratorsRetry() {
    if (!canManageRoles || moderatorsQuery.isFetching) {
      return;
    }

    void moderatorsQuery.refetch().catch(() => undefined);
  }

  function requestSearchRetry() {
    if (!canManageRoles || !isSearchActive || isSearchPending || searchQuery.isFetching) {
      return;
    }

    void searchQuery.refetch().catch(() => undefined);
  }

  async function refreshRoleQueries(userId?: string) {
    await Promise.allSettled([
      queryClient.invalidateQueries({
        queryKey: adminQueryKeys.usersRoot,
      }),
      queryClient.invalidateQueries({ queryKey: adminQueryKeys.users(searchQueryParams) }),
      userId
        ? queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(userId) })
        : Promise.resolve(),
    ]);
  }

  async function runPendingAction() {
    if (!pendingAction || isRoleActionDisabled || isRoleActionLocked()) {
      return;
    }

    if (!assertCanManageRoles()) {
      return;
    }

    roleActionInFlightRef.current = true;
    setIsSubmitting(true);
    try {
      await pendingAction.action();
      setToast({ type: "success", message: text.saved });
      setPendingAction(null);
      window.setTimeout(focusSearch, 0);
    } catch (error) {
      clientLogger.warn(
        "roles.action_failed",
        getRoleActionErrorDetails(error, pendingAction.targetUserId)
      );
      setToast({ type: "error", message: getAdminErrorMessage(error, text.failed) });
    } finally {
      roleActionInFlightRef.current = false;
      setIsSubmitting(false);
    }
  }

  function isRoleActionLocked(): boolean {
    return roleActionInFlightRef.current || isSubmitting;
  }

  function resetPendingRoleAction() {
    if (isRoleActionLocked()) {
      return;
    }

    setPendingAction(null);
  }

  function setAdminsPageContext(nextPage: number) {
    resetPendingRoleAction();
    setAdminsPage(Math.max(0, nextPage));
  }

  function setModeratorsPageContext(nextPage: number) {
    resetPendingRoleAction();
    setModeratorsPage(Math.max(0, nextPage));
  }

  function setSearchPageContext(nextPage: number) {
    resetPendingRoleAction();
    setSearchPage(Math.max(0, nextPage));
  }

  function assertCanManageRoles(): boolean {
    if (canManageRoles) {
      return true;
    }

    setPendingAction(null);
    setToast({ type: "error", message: text.roleActionsAdminOnly });
    return false;
  }

  function confirmAssignModerator(user: UserListItem) {
    if (isRoleActionDisabled || isRoleActionLocked() || !assertCanManageRoles()) {
      return;
    }

    setPendingAction({
      targetUserId: user.userId,
      title: text.confirmAssignTitle,
      description: `${text.confirmAssignDescription} ${userDisplayName(user)} · ${maskEmail(user.email)} · ${shortIdentifier(user.userId)}`,
      confirmLabel: text.assign,
      tone: "primary",
      action: async () => {
        await assignRole(user.userId, "Moderator");
        await refreshRoleQueries(user.userId);
      },
    });
  }

  function confirmRevokeModerator(user: UserListItem) {
    if (isRoleActionDisabled || isRoleActionLocked() || !assertCanManageRoles()) {
      return;
    }

    setPendingAction({
      targetUserId: user.userId,
      title: text.confirmRevokeTitle,
      description: `${text.confirmRevokeDescription} ${userDisplayName(user)} · ${maskEmail(user.email)} · ${shortIdentifier(user.userId)}`,
      confirmLabel: text.revoke,
      tone: "danger",
      action: async () => {
        await revokeRole(user.userId, "Moderator");
        if (moderators.length <= 1) {
          setModeratorsPage((currentPage) => Math.max(0, currentPage - 1));
        }

        await refreshRoleQueries(user.userId);
      },
    });
  }

  const adminsPageData = adminsQuery.isPlaceholderData ? undefined : adminsQuery.data;
  const moderatorsPageData = moderatorsQuery.isPlaceholderData ? undefined : moderatorsQuery.data;
  const searchPageData = searchQuery.isPlaceholderData ? undefined : searchQuery.data;
  const admins = adminsPageData?.items ?? [];
  const moderators = moderatorsPageData?.items ?? [];
  const searchResults = searchPageData?.items ?? [];
  const isAdminsRefreshing = adminsQuery.isFetching && adminsQuery.isPlaceholderData;
  const isModeratorsRefreshing = moderatorsQuery.isFetching && moderatorsQuery.isPlaceholderData;
  const isSearchRefreshing = searchQuery.isFetching && searchQuery.isPlaceholderData;
  const isSearchLoading =
    isSearchActive && (isSearchPending || searchQuery.isLoading || isSearchRefreshing);
  const hasSearchError = isSearchActive && !isSearchPending && searchQuery.isError;
  const visibleSearchResults =
    isSearchActive && !isSearchPending && !isSearchRefreshing ? searchResults : [];
  const visibleSearchResultCount = visibleSearchResults.length;
  const searchResultTotal = searchPageData?.totalCount ?? visibleSearchResultCount;
  const searchResultRangeStart = searchPage * SEARCH_PAGE_SIZE + 1;
  const searchResultRangeEnd = searchResultRangeStart + visibleSearchResultCount - 1;
  const searchStatusMessage =
    currentSearch.length === 0
      ? null
      : !isSearchActive
        ? text.searchMinimumCharacters
        : isSearchLoading
          ? text.searchStatusLoading
          : hasSearchError
            ? null
            : visibleSearchResultCount > 0
              ? `${text.searchResultsCount} ${searchResultRangeStart}–${searchResultRangeEnd} ${text.of} ${searchResultTotal}`
              : text.noSearchResults;
  const visibleActionUserIdSignature = [
    ...moderators.map((user) => user.userId),
    ...visibleSearchResults.map((user) => user.userId),
  ].join("|");
  const hasAnyRoleData = Boolean(adminsQuery.data || moderatorsQuery.data);
  const hasBlockingRoleError = isError && !hasAnyRoleData;

  useEffect(() => {
    let isActive = true;
    if (
      !pendingAction ||
      roleActionInFlightRef.current ||
      isSubmitting ||
      isModeratorsRefreshing ||
      isSearchRefreshing ||
      visibleActionUserIdSignature.split("|").includes(pendingAction.targetUserId)
    ) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setPendingAction(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [
    isModeratorsRefreshing,
    isSearchRefreshing,
    isSubmitting,
    pendingAction,
    visibleActionUserIdSignature,
  ]);

  return (
    <section className={styles.page}>
      {!canManageRoles || isLoading ? (
        <AdminStateCard title={text.loading} />
      ) : hasBlockingRoleError ? (
        <AdminStateCard
          title={text.error}
          description={getAdminErrorMessage(adminsQuery.error ?? moderatorsQuery.error, text.error)}
          tone="danger"
          action={
            <Button
              variant="secondary"
              size="sm"
              disabled={!canManageRoles || isRoleRetryFetching}
              onClick={requestRoleListsRetry}
            >
              {text.retry}
            </Button>
          }
        />
      ) : (
        <div className={styles.workspace}>
          <div className={styles.commandArea}>
            <label className={styles.visuallyHidden} htmlFor="role-user-search">
              {text.searchLabel}
            </label>
            <div className={styles.searchControl}>
              <SearchIcon className={styles.searchIcon} aria-hidden="true" />
              <input
                id="role-user-search"
                ref={searchInputRef}
                type="search"
                autoComplete="off"
                className={
                  search.length > 0 ? `${styles.input} ${styles.inputWithClear}` : styles.input
                }
                aria-describedby={searchStatusMessage ? "role-search-status" : undefined}
                value={search}
                onChange={(event) => setSearchContext(event.target.value)}
                maxLength={USER_SEARCH_MAX_LENGTH}
                placeholder={text.searchPlaceholder}
              />
              {search.length > 0 ? (
                <Button
                  variant="ghost"
                  size="sm"
                  className={styles.clearSearch}
                  aria-label={text.clearSearch}
                  title={text.clearSearch}
                  onClick={clearSearch}
                >
                  <CancelCircleIcon className={styles.clearSearchIcon} />
                </Button>
              ) : null}
            </div>

            {searchStatusMessage ? (
              <p id="role-search-status" className={styles.searchStatus} role="status">
                {searchStatusMessage}
              </p>
            ) : null}

            {isSearchActive ? (
              <div
                className={styles.searchResults}
                aria-busy={isSearchLoading ? "true" : undefined}
              >
                {hasSearchError ? (
                  <AdminStateCard
                    title={text.searchError}
                    description={getAdminErrorMessage(searchQuery.error, text.searchError)}
                    tone="danger"
                    action={
                      <Button
                        variant="secondary"
                        size="sm"
                        disabled={!canManageRoles || searchQuery.isFetching}
                        onClick={requestSearchRetry}
                      >
                        {text.retry}
                      </Button>
                    }
                  />
                ) : !isSearchLoading ? (
                  <>
                    <div className={styles.userList}>
                      {visibleSearchResults.map((user) => {
                        const existingManagedRole = getExistingManagedRole(user, text);

                        return (
                          <UserRow
                            key={user.userId}
                            user={user}
                            locale={locale}
                            text={text}
                            action={
                              existingManagedRole ? (
                                <span className={styles.existingRole}>{existingManagedRole}</span>
                              ) : (
                                <Button
                                  variant="primary"
                                  size="sm"
                                  aria-label={`${text.assignModeratorLabel} ${userDisplayName(user)}`}
                                  disabled={!canManageRoles || isRoleActionDisabled}
                                  onClick={() => confirmAssignModerator(user)}
                                >
                                  <PlusIcon className={styles.buttonIcon} />
                                  {text.assign}
                                </Button>
                              )
                            }
                          />
                        );
                      })}
                    </div>
                    {searchPageData && searchPageData.totalCount > 0 ? (
                      <RolePager
                        text={text}
                        label={text.searchPaginationLabel}
                        pageIndex={searchPage}
                        pageSize={SEARCH_PAGE_SIZE}
                        totalCount={searchPageData.totalCount}
                        hasMore={searchPageData.hasMore}
                        isFetching={searchQuery.isFetching}
                        onPrevious={() => setSearchPageContext(searchPage - 1)}
                        onNext={() => setSearchPageContext(searchPage + 1)}
                      />
                    ) : null}
                  </>
                ) : null}
              </div>
            ) : null}
          </div>

          <div className={styles.directory}>
            <section className={styles.roleGroup} aria-labelledby="role-admins-title">
              <header className={styles.roleGroupHeader}>
                <h2 id="role-admins-title" className={styles.roleGroupTitle}>
                  {text.adminsTitle}{" "}
                  <span className={styles.roleCount}>
                    · {adminsPageData ? adminsPageData.totalCount : "—"}
                  </span>
                </h2>
              </header>
              <div className={styles.userList}>
                {isAdminsRefreshing ? (
                  <AdminStateCard title={text.loading} />
                ) : adminsQuery.isError ? (
                  <AdminStateCard
                    title={text.adminsError}
                    description={getAdminErrorMessage(adminsQuery.error, text.adminsError)}
                    tone="warning"
                    action={
                      <Button
                        variant="secondary"
                        size="sm"
                        disabled={!canManageRoles || adminsQuery.isFetching}
                        onClick={requestAdminsRetry}
                      >
                        {text.retry}
                      </Button>
                    }
                  />
                ) : admins.length === 0 ? (
                  <AdminStateCard title={text.emptyAdmins} />
                ) : null}
                {admins.map((user) => (
                  <UserRow key={user.userId} user={user} locale={locale} text={text} />
                ))}
              </div>
              {adminsPageData && adminsPageData.totalCount > 0 ? (
                <RolePager
                  text={text}
                  label={text.adminsPaginationLabel}
                  pageIndex={adminsPage}
                  pageSize={PAGE_SIZE}
                  totalCount={adminsPageData.totalCount}
                  hasMore={adminsPageData.hasMore}
                  isFetching={adminsQuery.isFetching}
                  onPrevious={() => setAdminsPageContext(adminsPage - 1)}
                  onNext={() => setAdminsPageContext(adminsPage + 1)}
                />
              ) : null}
            </section>

            <section className={styles.roleGroup} aria-labelledby="role-moderators-title">
              <header className={styles.roleGroupHeader}>
                <h2 id="role-moderators-title" className={styles.roleGroupTitle}>
                  {text.moderatorsTitle}{" "}
                  <span className={styles.roleCount}>
                    · {moderatorsPageData ? moderatorsPageData.totalCount : "—"}
                  </span>
                </h2>
              </header>
              <div className={styles.userList}>
                {isModeratorsRefreshing ? (
                  <AdminStateCard title={text.loading} />
                ) : moderatorsQuery.isError ? (
                  <AdminStateCard
                    title={text.moderatorsError}
                    description={getAdminErrorMessage(moderatorsQuery.error, text.moderatorsError)}
                    tone="warning"
                    action={
                      <Button
                        variant="secondary"
                        size="sm"
                        disabled={!canManageRoles || moderatorsQuery.isFetching}
                        onClick={requestModeratorsRetry}
                      >
                        {text.retry}
                      </Button>
                    }
                  />
                ) : moderators.length === 0 ? (
                  <div className={styles.emptyModerators} role="status">
                    <PeopleIcon className={styles.emptyModeratorsIcon} aria-hidden="true" />
                    <span>{text.emptyModerators}</span>
                  </div>
                ) : null}
                {moderators.map((user) => (
                  <UserRow
                    key={user.userId}
                    user={user}
                    locale={locale}
                    text={text}
                    action={
                      <Button
                        variant="danger"
                        size="sm"
                        aria-label={`${text.revokeModeratorLabel} ${userDisplayName(user)}`}
                        disabled={!canManageRoles || isRoleActionDisabled}
                        onClick={() => confirmRevokeModerator(user)}
                      >
                        {text.revoke}
                      </Button>
                    }
                  />
                ))}
              </div>
              {moderatorsPageData && moderatorsPageData.totalCount > 0 ? (
                <RolePager
                  text={text}
                  label={text.moderatorsPaginationLabel}
                  pageIndex={moderatorsPage}
                  pageSize={PAGE_SIZE}
                  totalCount={moderatorsPageData.totalCount}
                  hasMore={moderatorsPageData.hasMore}
                  isFetching={moderatorsQuery.isFetching}
                  onPrevious={() => setModeratorsPageContext(moderatorsPage - 1)}
                  onNext={() => setModeratorsPageContext(moderatorsPage + 1)}
                />
              ) : null}
            </section>
          </div>
        </div>
      )}

      <ConfirmationDialog
        open={Boolean(pendingAction)}
        title={pendingAction?.title ?? ""}
        description={pendingAction?.description ?? ""}
        confirmLabel={pendingAction?.confirmLabel ?? text.assign}
        cancelLabel={text.cancel}
        tone={pendingAction?.tone ?? "primary"}
        isSubmitting={isSubmitting}
        onConfirm={runPendingAction}
        onCancel={() => {
          if (!roleActionInFlightRef.current && !isSubmitting) {
            setPendingAction(null);
          }
        }}
      />
      {toast ? <Toast type={toast.type} message={toast.message} /> : null}
    </section>
  );
}
