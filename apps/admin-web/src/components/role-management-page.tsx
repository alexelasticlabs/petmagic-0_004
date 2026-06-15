"use client";

import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { type ReactNode } from "react";
import { useEffect, useMemo, useRef, useState } from "react";

import { CaretDownIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/role-management-page.module.css";
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
import { formatDateTime } from "@/lib/format-date-time";
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

function getCopy(locale: Locale) {
  const isRu = locale === "ru";
  return {
    eyebrow: isRu ? "Контроль доступа" : "Access control",
    title: isRu ? "Управление ролями" : "Role Management",
    description: isRu
      ? "Admin и Moderator управляются из этой панели. Premium не считается ролью."
      : "Admin and Moderator are managed from this panel. Premium is not a role.",
    adminOnly: isRu ? "Только Admin" : "Admin only",
    adminsTitle: isRu ? "Администраторы" : "Admins",
    adminsDescription: isRu
      ? "Список пользователей с полным доступом. Последнего Admin нельзя понизить."
      : "Users with full access. The last Admin cannot be downgraded.",
    moderatorsTitle: isRu ? "Модераторы" : "Moderators",
    moderatorsDescription: isRu
      ? "Пользователи с ограниченным доступом к разрешенным разделам."
      : "Users with limited access to permitted sections.",
    searchTitle: isRu ? "Назначить Moderator" : "Assign Moderator",
    searchDescription: isRu ? "Поиск по email, id или имени." : "Search by email, id, or name.",
    searchLabel: isRu ? "Пользователь" : "User",
    searchPlaceholder: isRu ? "email, user id или имя" : "email, user id, or name",
    searchHint: isRu
      ? "Введите минимум 2 символа. Поиск обновится автоматически."
      : "Enter at least 2 characters. Search updates automatically.",
    loading: isRu ? "Загрузка ролей" : "Loading roles",
    error: isRu ? "Не удалось загрузить роли" : "Failed to load roles",
    adminsError: isRu ? "Не удалось загрузить Admin" : "Failed to load admins",
    moderatorsError: isRu ? "Не удалось загрузить Moderator" : "Failed to load moderators",
    searchError: isRu ? "Не удалось выполнить поиск пользователей" : "Failed to search users",
    emptyAdmins: isRu ? "Admin не найдены" : "No admins found",
    emptyModerators: isRu ? "Moderator не найдены" : "No moderators found",
    emptySearch: isRu ? "Введите запрос для поиска пользователя" : "Enter a query to search users",
    noSearchResults: isRu ? "Пользователи не найдены" : "No users found",
    assign: isRu ? "Назначить" : "Assign",
    revoke: isRu ? "Снять Moderator" : "Remove Moderator",
    adminAlreadyPrivileged: isRu ? "Уже Admin" : "Already Admin",
    moderatorAlreadyPrivileged: isRu ? "Уже Moderator" : "Already Moderator",
    cancel: isRu ? "Отмена" : "Cancel",
    confirmAssignTitle: isRu ? "Назначить Moderator?" : "Assign Moderator?",
    confirmAssignDescription: isRu
      ? "Пользователь получит доступ к разрешенным moderator разделам."
      : "The user will get access to permitted moderator sections.",
    confirmRevokeTitle: isRu ? "Снять Moderator?" : "Remove Moderator?",
    confirmRevokeDescription: isRu
      ? "Пользователь потеряет moderator доступ. Действие будет записано в audit log."
      : "The user will lose moderator access. The action will be written to audit log.",
    saved: isRu ? "Роль обновлена" : "Role updated",
    failed: isRu ? "Не удалось обновить роль" : "Failed to update role",
    roleActionsAdminOnly: isRu
      ? "Изменять роли может только Admin."
      : "Only Admin can change roles.",
    assignModeratorLabel: isRu ? "Назначить Moderator пользователю" : "Assign Moderator to",
    revokeModeratorLabel: isRu ? "Снять Moderator у пользователя" : "Remove Moderator from",
    created: isRu ? "Создан" : "Created",
    retry: isRu ? "Повторить" : "Retry",
    previous: isRu ? "Назад" : "Previous",
    next: isRu ? "Вперёд" : "Next",
    previousPageLabel: isRu ? "Предыдущая страница списка ролей" : "Previous role list page",
    nextPageLabel: isRu ? "Следующая страница списка ролей" : "Next role list page",
    page: isRu ? "Страница" : "Page",
    of: isRu ? "из" : "of",
    showing: isRu ? "Показано" : "Showing",
    users: isRu ? "пользователей" : "users",
  };
}

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
      error instanceof Error ? sanitizeSensitiveText(error.message, 160) : "unknown_error",
  };
}

function UserRoles({ roles }: { roles: readonly string[] }) {
  return (
    <span className={styles.roleBadges}>
      {roles.map((role) => (
        <AdminBadge
          key={role}
          tone={role === "Admin" ? "danger" : role === "Moderator" ? "info" : "neutral"}
        >
          {sanitizeSensitiveText(role, 32)}
        </AdminBadge>
      ))}
    </span>
  );
}

function UserRow({
  user,
  locale,
  action,
}: {
  user: UserListItem;
  locale: Locale;
  action?: ReactNode;
}) {
  const text = getCopy(locale);

  return (
    <div className={styles.userRow}>
      <div className={styles.userMain}>
        <strong className={styles.userName}>{userDisplayName(user)}</strong>
        <span className={styles.userMeta}>{maskEmail(user.email)}</span>
        <span className={styles.userMeta}>
          {shortIdentifier(user.userId)} / {text.created}:{" "}
          {formatDateTime(user.createdAtUtc, locale)}
        </span>
        <UserRoles roles={user.roles} />
      </div>
      {action}
    </div>
  );
}

function RolePager({
  locale,
  pageIndex,
  pageSize,
  totalCount,
  hasMore,
  isFetching,
  onPrevious,
  onNext,
}: {
  locale: Locale;
  pageIndex: number;
  pageSize: number;
  totalCount: number;
  hasMore: boolean;
  isFetching: boolean;
  onPrevious: () => void;
  onNext: () => void;
}) {
  const text = getCopy(locale);
  const pageCount = Math.max(1, Math.ceil(totalCount / pageSize));
  const shownStart = totalCount > 0 ? pageIndex * pageSize + 1 : 0;
  const shownEnd = Math.min(totalCount, (pageIndex + 1) * pageSize);

  return (
    <div className={styles.pager}>
      <span className={styles.pageInfo}>
        {text.showing} {shownStart}-{shownEnd} {text.of} {totalCount} {text.users}
      </span>
      <span className={styles.pageInfo}>
        {text.page} {pageIndex + 1} {text.of} {pageCount}
      </span>
      <div className={styles.pagerActions}>
        <button
          type="button"
          className={`${styles.button} ${styles.pagerButton}`}
          disabled={pageIndex === 0 || isFetching}
          aria-label={text.previousPageLabel}
          title={text.previousPageLabel}
          onClick={onPrevious}
        >
          <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
        </button>
        <button
          type="button"
          className={`${styles.button} ${styles.pagerButton}`}
          disabled={!hasMore || isFetching}
          aria-label={text.nextPageLabel}
          title={text.nextPageLabel}
          onClick={onNext}
        >
          <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
        </button>
      </div>
    </div>
  );
}

export function RoleManagementPage({ locale }: RoleManagementPageProps) {
  const text = getCopy(locale);
  const queryClient = useQueryClient();
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canManageRoles = sessionRoles.includes("Admin");
  const [search, setSearch] = useState("");
  const [adminsPage, setAdminsPage] = useState(0);
  const [moderatorsPage, setModeratorsPage] = useState(0);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const roleActionInFlightRef = useRef(false);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const debouncedSearch = useDebouncedValue(search, 350);
  const normalizedSearch = debouncedSearch.trim();

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
    () => ({ search: normalizedSearch, take: 12 }),
    [normalizedSearch]
  );
  const searchQuery = useQuery({
    queryKey: adminQueryKeys.users(searchQueryParams),
    queryFn: ({ signal }) => fetchUsers(searchQueryParams, signal),
    enabled: canManageRoles && normalizedSearch.length >= 2,
    placeholderData: keepPreviousData,
  });

  const isLoading = adminsQuery.isLoading || moderatorsQuery.isLoading;
  const isError = adminsQuery.isError || moderatorsQuery.isError;
  const isRoleRetryFetching = adminsQuery.isFetching || moderatorsQuery.isFetching;
  const isRoleDataFetching = isRoleRetryFetching || searchQuery.isFetching;
  const isRoleActionDisabled = isSubmitting || isRoleDataFetching;

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
    if (!canManageRoles || searchQuery.isFetching) {
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
      description: `${text.confirmAssignDescription} ${userDisplayName(user)}`,
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
      description: `${text.confirmRevokeDescription} ${userDisplayName(user)}`,
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
  const admins = adminsPageData?.items ?? [];
  const moderators = moderatorsPageData?.items ?? [];
  const searchResults = searchQuery.data?.items ?? [];
  const isSearchActive = normalizedSearch.length >= 2;
  const isAdminsRefreshing = adminsQuery.isFetching && adminsQuery.isPlaceholderData;
  const isModeratorsRefreshing = moderatorsQuery.isFetching && moderatorsQuery.isPlaceholderData;
  const isSearchRefreshing = searchQuery.isFetching && searchQuery.isPlaceholderData;
  const visibleSearchResults = isSearchActive && !isSearchRefreshing ? searchResults : [];
  const visibleActionUserIdSignature = [
    ...moderators.map((user) => user.userId),
    ...visibleSearchResults.map((user) => user.userId),
  ].join("|");
  const hasAnyRoleData = Boolean(adminsQuery.data || moderatorsQuery.data);
  const hasBlockingRoleError = isError && !hasAnyRoleData;

  useEffect(() => {
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

    queueMicrotask(() => setPendingAction(null));
  }, [
    isModeratorsRefreshing,
    isSearchRefreshing,
    isSubmitting,
    pendingAction,
    visibleActionUserIdSignature,
  ]);

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
      />

      {!canManageRoles || isLoading ? (
        <AdminStateCard title={text.loading} />
      ) : hasBlockingRoleError ? (
        <AdminStateCard
          title={text.error}
          description={getAdminErrorMessage(adminsQuery.error ?? moderatorsQuery.error, text.error)}
          tone="danger"
          action={
            <button
              type="button"
              className={styles.button}
              disabled={!canManageRoles || isRoleRetryFetching}
              onClick={requestRoleListsRetry}
            >
              {text.retry}
            </button>
          }
        />
      ) : (
        <div className={styles.grid}>
          <AdminCard title={text.adminsTitle} description={text.adminsDescription}>
            <div className={styles.userList}>
              {isAdminsRefreshing ? (
                <AdminStateCard title={text.loading} />
              ) : adminsQuery.isError ? (
                <AdminStateCard
                  title={text.adminsError}
                  description={getAdminErrorMessage(adminsQuery.error, text.adminsError)}
                  tone="warning"
                  action={
                    <button
                      type="button"
                      className={styles.button}
                      disabled={!canManageRoles || adminsQuery.isFetching}
                      onClick={requestAdminsRetry}
                    >
                      {text.retry}
                    </button>
                  }
                />
              ) : admins.length === 0 ? (
                <AdminStateCard title={text.emptyAdmins} />
              ) : null}
              {admins.map((user) => (
                <UserRow key={user.userId} user={user} locale={locale} />
              ))}
            </div>
            {adminsPageData && adminsPageData.totalCount > 0 ? (
              <RolePager
                locale={locale}
                pageIndex={adminsPage}
                pageSize={PAGE_SIZE}
                totalCount={adminsPageData.totalCount}
                hasMore={adminsPageData.hasMore}
                isFetching={adminsQuery.isFetching}
                onPrevious={() => setAdminsPageContext(adminsPage - 1)}
                onNext={() => setAdminsPageContext(adminsPage + 1)}
              />
            ) : null}
          </AdminCard>

          <AdminCard title={text.moderatorsTitle} description={text.moderatorsDescription}>
            <div className={styles.userList}>
              {isModeratorsRefreshing ? (
                <AdminStateCard title={text.loading} />
              ) : moderatorsQuery.isError ? (
                <AdminStateCard
                  title={text.moderatorsError}
                  description={getAdminErrorMessage(moderatorsQuery.error, text.moderatorsError)}
                  tone="warning"
                  action={
                    <button
                      type="button"
                      className={styles.button}
                      disabled={!canManageRoles || moderatorsQuery.isFetching}
                      onClick={requestModeratorsRetry}
                    >
                      {text.retry}
                    </button>
                  }
                />
              ) : moderators.length === 0 ? (
                <AdminStateCard title={text.emptyModerators} />
              ) : null}
              {moderators.map((user) => (
                <UserRow
                  key={user.userId}
                  user={user}
                  locale={locale}
                  action={
                    <button
                      type="button"
                      className={`${styles.button} ${styles.buttonDanger}`}
                      aria-label={`${text.revokeModeratorLabel} ${userDisplayName(user)}`}
                      disabled={!canManageRoles || isRoleActionDisabled}
                      onClick={() => confirmRevokeModerator(user)}
                    >
                      {text.revoke}
                    </button>
                  }
                />
              ))}
            </div>
            {moderatorsPageData && moderatorsPageData.totalCount > 0 ? (
              <RolePager
                locale={locale}
                pageIndex={moderatorsPage}
                pageSize={PAGE_SIZE}
                totalCount={moderatorsPageData.totalCount}
                hasMore={moderatorsPageData.hasMore}
                isFetching={moderatorsQuery.isFetching}
                onPrevious={() => setModeratorsPageContext(moderatorsPage - 1)}
                onNext={() => setModeratorsPageContext(moderatorsPage + 1)}
              />
            ) : null}
          </AdminCard>
        </div>
      )}

      {canManageRoles ? (
        <AdminCard title={text.searchTitle} description={text.searchDescription}>
          <div className={styles.search}>
            <label className={styles.field}>
              <span className={styles.label}>{text.searchLabel}</span>
              <input
                type="search"
                autoComplete="off"
                className={styles.input}
                aria-describedby="role-search-hint"
                value={search}
                onChange={(event) => {
                  resetPendingRoleAction();
                  setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));
                }}
                maxLength={USER_SEARCH_MAX_LENGTH}
                placeholder={text.searchPlaceholder}
              />
              <span id="role-search-hint" className={styles.hint}>
                {text.searchHint}
              </span>
            </label>
          </div>
          <div className={styles.userList}>
            {!isSearchActive ? <AdminStateCard title={text.emptySearch} /> : null}
            {isSearchActive && (searchQuery.isLoading || isSearchRefreshing) ? (
              <AdminStateCard title={text.loading} />
            ) : null}
            {isSearchActive && searchQuery.isError ? (
              <AdminStateCard
                title={text.searchError}
                description={getAdminErrorMessage(searchQuery.error, text.searchError)}
                tone="danger"
                action={
                  <button
                    type="button"
                    className={styles.button}
                    disabled={!canManageRoles || searchQuery.isFetching}
                    onClick={requestSearchRetry}
                  >
                    {text.retry}
                  </button>
                }
              />
            ) : null}
            {isSearchActive &&
            !searchQuery.isLoading &&
            !isSearchRefreshing &&
            !searchQuery.isError &&
            visibleSearchResults.length === 0 ? (
              <AdminStateCard title={text.noSearchResults} />
            ) : null}
            {visibleSearchResults.map((user) => {
              const isAdmin = user.roles.includes("Admin");
              const isModerator = user.roles.includes("Moderator");
              return (
                <UserRow
                  key={user.userId}
                  user={user}
                  locale={locale}
                  action={
                    <button
                      type="button"
                      className={styles.button}
                      aria-label={`${text.assignModeratorLabel} ${userDisplayName(user)}`}
                      disabled={!canManageRoles || isAdmin || isModerator || isRoleActionDisabled}
                      onClick={() => confirmAssignModerator(user)}
                    >
                      {isAdmin
                        ? text.adminAlreadyPrivileged
                        : isModerator
                          ? text.moderatorAlreadyPrivileged
                          : text.assign}
                    </button>
                  }
                />
              );
            })}
          </div>
        </AdminCard>
      ) : null}

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
