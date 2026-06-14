"use client";

import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { type ReactNode } from "react";
import { useEffect, useMemo, useRef, useState } from "react";

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
    loading: isRu ? "Загрузка ролей" : "Loading roles",
    error: isRu ? "Не удалось загрузить роли" : "Failed to load roles",
    searchError: isRu ? "Не удалось выполнить поиск пользователей" : "Failed to search users",
    emptyAdmins: isRu ? "Admin не найдены" : "No admins found",
    emptyModerators: isRu ? "Moderator не найдены" : "No moderators found",
    emptySearch: isRu ? "Введите запрос для поиска пользователя" : "Enter a query to search users",
    noSearchResults: isRu ? "Пользователи не найдены" : "No users found",
    assign: isRu ? "Назначить" : "Assign",
    revoke: isRu ? "Снять Moderator" : "Remove Moderator",
    adminAlreadyPrivileged: isRu ? "Admin" : "Admin",
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
          className={styles.button}
          disabled={pageIndex === 0 || isFetching}
          aria-label={text.previousPageLabel}
          onClick={onPrevious}
        >
          {text.previous}
        </button>
        <button
          type="button"
          className={styles.button}
          disabled={!hasMore || isFetching}
          aria-label={text.nextPageLabel}
          onClick={onNext}
        >
          {text.next}
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
    () => ({ search: debouncedSearch, take: 12 }),
    [debouncedSearch]
  );
  const searchQuery = useQuery({
    queryKey: adminQueryKeys.users(searchQueryParams),
    queryFn: ({ signal }) => fetchUsers(searchQueryParams, signal),
    enabled: canManageRoles && debouncedSearch.trim().length >= 2,
    placeholderData: keepPreviousData,
  });

  const isLoading = adminsQuery.isLoading || moderatorsQuery.isLoading;
  const isError = adminsQuery.isError || moderatorsQuery.isError;

  async function refreshRoleQueries(userId?: string) {
    await Promise.all([
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
    if (!pendingAction || roleActionInFlightRef.current || isSubmitting) {
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
      setToast({ type: "error", message: getAdminErrorMessage(error, text.failed) });
    } finally {
      roleActionInFlightRef.current = false;
      setIsSubmitting(false);
    }
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
    if (!assertCanManageRoles()) {
      return;
    }

    setPendingAction({
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
    if (!assertCanManageRoles()) {
      return;
    }

    setPendingAction({
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

  const admins = adminsQuery.data?.items ?? [];
  const moderators = moderatorsQuery.data?.items ?? [];
  const searchResults = searchQuery.data?.items ?? [];
  const isRoleRetryFetching = adminsQuery.isFetching || moderatorsQuery.isFetching;
  const isSearchActive = debouncedSearch.trim().length >= 2;

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
      ) : isError ? (
        <AdminStateCard
          title={text.error}
          tone="danger"
          action={
            <button
              type="button"
              className={styles.button}
              disabled={!canManageRoles || isRoleRetryFetching}
              onClick={() => {
                if (!canManageRoles) {
                  return;
                }

                void Promise.all([adminsQuery.refetch(), moderatorsQuery.refetch()]).catch(
                  () => undefined
                );
              }}
            >
              {text.retry}
            </button>
          }
        />
      ) : (
        <div className={styles.grid}>
          <AdminCard title={text.adminsTitle} description={text.adminsDescription}>
            <div className={styles.userList}>
              {admins.length === 0 ? <AdminStateCard title={text.emptyAdmins} /> : null}
              {admins.map((user) => (
                <UserRow key={user.userId} user={user} locale={locale} />
              ))}
            </div>
            {adminsQuery.data && adminsQuery.data.totalCount > 0 ? (
              <RolePager
                locale={locale}
                pageIndex={adminsPage}
                pageSize={PAGE_SIZE}
                totalCount={adminsQuery.data.totalCount}
                hasMore={adminsQuery.data.hasMore}
                isFetching={adminsQuery.isFetching}
                onPrevious={() => setAdminsPage((currentPage) => Math.max(0, currentPage - 1))}
                onNext={() => setAdminsPage((currentPage) => currentPage + 1)}
              />
            ) : null}
          </AdminCard>

          <AdminCard title={text.moderatorsTitle} description={text.moderatorsDescription}>
            <div className={styles.userList}>
              {moderators.length === 0 ? <AdminStateCard title={text.emptyModerators} /> : null}
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
                      disabled={!canManageRoles || isSubmitting}
                      onClick={() => confirmRevokeModerator(user)}
                    >
                      {text.revoke}
                    </button>
                  }
                />
              ))}
            </div>
            {moderatorsQuery.data && moderatorsQuery.data.totalCount > 0 ? (
              <RolePager
                locale={locale}
                pageIndex={moderatorsPage}
                pageSize={PAGE_SIZE}
                totalCount={moderatorsQuery.data.totalCount}
                hasMore={moderatorsQuery.data.hasMore}
                isFetching={moderatorsQuery.isFetching}
                onPrevious={() => setModeratorsPage((currentPage) => Math.max(0, currentPage - 1))}
                onNext={() => setModeratorsPage((currentPage) => currentPage + 1)}
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
                value={search}
                onChange={(event) => setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH))}
                maxLength={USER_SEARCH_MAX_LENGTH}
                placeholder={text.searchPlaceholder}
              />
            </label>
          </div>
          <div className={styles.userList}>
            {!isSearchActive ? <AdminStateCard title={text.emptySearch} /> : null}
            {isSearchActive && searchQuery.isLoading ? (
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
                    onClick={() => {
                      if (!canManageRoles) {
                        return;
                      }

                      void searchQuery.refetch().catch(() => undefined);
                    }}
                  >
                    {text.retry}
                  </button>
                }
              />
            ) : null}
            {isSearchActive &&
            !searchQuery.isLoading &&
            !searchQuery.isError &&
            searchResults.length === 0 ? (
              <AdminStateCard title={text.noSearchResults} />
            ) : null}
            {searchResults.map((user) => {
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
                      disabled={!canManageRoles || isAdmin || isModerator || isSubmitting}
                      onClick={() => confirmAssignModerator(user)}
                    >
                      {isAdmin
                        ? text.adminAlreadyPrivileged
                        : isModerator
                          ? "Moderator"
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
