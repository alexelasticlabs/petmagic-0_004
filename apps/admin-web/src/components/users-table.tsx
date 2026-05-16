"use client";

import { AdminCard, AdminPageHero, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import styles from "@/components/users-table.module.css";
import {
    assignRole,
    fetchUsers,
    getSession,
    revokeRole,
    setActive,
    setPremium,
    useAuthSession,
    type UserListItem
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useEffectEvent, useState } from "react";

type UsersTableProps = {
  locale: Locale;
};

export function UsersTable({ locale }: UsersTableProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const session = useAuthSession();

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2400);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const canManageRoles = session?.user.roles.includes("Admin") ?? false;
  const hero = (
    <AdminPageHero
      eyebrow={locale === "ru" ? "Access control" : "Access control"}
      title={text.usersTitle}
      description={locale === "ru"
        ? "Управление ролями, premium-статусом и активностью пользователей в том же визуальном ритме, что и каталог, editor и dashboard."
        : "Manage roles, premium status, and activity with the same visual rhythm as the catalog, editor, and dashboard."}
      badge={locale === "ru" ? "Роли и доступ" : "Roles & access"}
      metaItems={[
        locale === "ru" ? `Пользователей: ${users.length}` : `Users: ${users.length}`,
        canManageRoles ? (locale === "ru" ? "Admin controls enabled" : "Admin controls enabled") : (locale === "ru" ? "Просмотр без admin-control" : "View only"),
        locale === "ru" ? "Живое управление статусами" : "Live status controls",
      ]}
    />
  );

  async function loadUsers() {
    setIsLoading(true);
    setError(null);

    try {
      const session = getSession();
      if (!session) {
        router.replace(`/${locale}`);
        return;
      }

      const response = await fetchUsers();
      setUsers(response);
    } catch {
      setError(text.errorLoadingUsers);
      setToast({ type: "error", message: text.errorLoadingUsers });
    } finally {
      setIsLoading(false);
    }
  }

  const loadUsersOnMount = useEffectEvent(loadUsers);

  useEffect(() => {
    queueMicrotask(() => {
      void loadUsersOnMount();
    });
  }, []);

  async function runAction(userId: string, action: () => Promise<void>) {
    setBusyUserId(userId);
    setError(null);

    try {
      await action();
      await loadUsers();
      setToast({
        type: "success",
        message: locale === "ru" ? "Изменения сохранены" : "Changes saved",
      });
    } catch {
      setError(text.errorLoadingUsers);
      setToast({ type: "error", message: text.errorLoadingUsers });
    } finally {
      setBusyUserId(null);
    }
  }

  if (isLoading) {
    return (
      <div className={styles.page}>
        {hero}
        <AdminCard title={text.usersTitle} description={locale === "ru" ? "Загрузка списка пользователей" : "Loading users list"}>
          <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
            {Array.from({ length: 6 }).map((_, index) => (
              <div key={index} className={styles.skeletonLine} />
            ))}
          </div>
        </AdminCard>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      {hero}
      <AdminCard
        title={text.usersTitle}
        description={locale === "ru" ? "Роли, премиум-статус и активность пользователей" : "Roles, premium status, and user access controls"}
      >
        {error ? <p className={styles.message}>{error}</p> : null}

        {!users.length ? (
          <div className={styles.emptyState}>
            <p className={styles.emptyTitle}>{text.noUsers}</p>
            <p className={styles.emptyDescription}>{text.loading}</p>
          </div>
        ) : null}

        {!!users.length && (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.emailLabel}</th>
                <th>{text.roleLabel}</th>
                <th>{text.premiumLabel}</th>
                <th>{text.activeLabel}</th>
                <th>{text.actionsLabel}</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const isBusy = busyUserId === user.userId;
                const isModerator = user.roles.includes("Moderator");
                const isAdmin = user.roles.includes("Admin");

                return (
                  <tr key={user.userId}>
                    <td data-label={text.emailLabel}>{user.email}</td>
                    <td data-label={text.roleLabel}>
                      <div className={styles.roleList}>
                        {user.roles.map((role) => (
                          <span key={role} className={styles.rolePill}>{role}</span>
                        ))}
                      </div>
                    </td>
                    <td data-label={text.premiumLabel}>
                      <AdminStatusBadge color={user.isPremium ? "#22c55e" : "#8da1ba"}>
                        {user.isPremium ? "Yes" : "No"}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.activeLabel}>
                      <AdminStatusBadge color={user.isActive ? "#2dd4bf" : "#f87171"}>
                        {user.isActive ? "Yes" : "No"}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.actionsLabel} className={styles.actionsCell}>
                      <div className={styles.actions}>
                        <Button
                          variant="secondary"
                          size="sm"
                          className={styles.adminButtonPrimary}
                          disabled={isBusy}
                          onClick={() => runAction(user.userId, () => setPremium(user.userId, !user.isPremium))}
                        >
                          {user.isPremium ? text.removePremium : text.makePremium}
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          className={styles.adminButton}
                          disabled={isBusy}
                          onClick={() => runAction(user.userId, () => setActive(user.userId, !user.isActive))}
                        >
                          {user.isActive ? text.deactivate : text.activate}
                        </Button>
                        {canManageRoles && (
                          <>
                            <Button
                              variant="ghost"
                              size="sm"
                              className={styles.adminButton}
                              disabled={isBusy}
                              onClick={() =>
                                runAction(user.userId, () =>
                                  isModerator ? revokeRole(user.userId, "Moderator") : assignRole(user.userId, "Moderator")
                                )
                              }
                            >
                              {isModerator ? text.revokeModerator : text.assignModerator}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              className={styles.adminButton}
                              disabled={isBusy}
                              onClick={() =>
                                runAction(user.userId, () =>
                                  isAdmin ? revokeRole(user.userId, "Admin") : assignRole(user.userId, "Admin")
                                )
                              }
                            >
                              {isAdmin ? text.revokeAdmin : text.assignAdmin}
                            </Button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
            </table>
          </div>
        )}
      </AdminCard>

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </div>
  );
}
