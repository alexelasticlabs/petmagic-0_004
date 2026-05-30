"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";

import {
  CancelCircleIcon,
  DollarIcon,
  MoreHorizontalIcon,
  RefreshIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminPage,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
  type AdminTone,
} from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import styles from "@/components/users-table.module.css";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { UserAvatarView } from "@/components/users/user-avatar";
import {
  adjustAdminUserWallet,
  assignRole,
  deleteAdminUser,
  revokePremium,
  revokeRole,
  setActive,
  setPremium,
} from "@/lib/api-client";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";

type UsersTableProps = {
  locale: Locale;
};

type ActionsMenuPosition = {
  top: number;
  left: number;
  minWidth: number;
  openUpward: boolean;
};

type UserRoleText = Pick<Dictionary, "userRoleAdmin" | "userRoleModerator" | "userRoleUser">;

function getUserRoleLabel(role: string, text: UserRoleText) {
  return role === "Admin"
    ? text.userRoleAdmin
    : role === "Moderator"
      ? text.userRoleModerator
      : role === "User"
        ? text.userRoleUser
        : role;
}

function getUserRoleTone(role: string): AdminTone {
  if (role === "Admin") {
    return "danger";
  }

  if (role === "Moderator") {
    return "info";
  }

  return "neutral";
}

export function UsersTable({ locale }: UsersTableProps) {
  const text = getDictionary(locale);
  const [openActionsUserId, setOpenActionsUserId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);
  const menuRootRef = useRef<HTMLDivElement | null>(null);
  const triggerRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const { busyUserId, canManageRoles, error, isLoading, runAction, toast, users } =
    useUsersAdmin(locale);

  const closeActionsMenu = useCallback(() => {
    setOpenActionsUserId(null);
    setActionsMenuPosition(null);
  }, []);

  const estimateActionsMenuHeight = useMemo(() => {
    const itemCount = canManageRoles ? 7 : 4;
    return itemCount * 36 + 18;
  }, [canManageRoles]);

  const updateActionsMenuPosition = useCallback(
    (userId: string) => {
      const trigger = triggerRefs.current[userId];
      if (!trigger) {
        closeActionsMenu();
        return;
      }

      const triggerRect = trigger.getBoundingClientRect();
      const gap = 6;
      const viewportPadding = 8;
      const minWidth = 216;
      const availableBelow = window.innerHeight - triggerRect.bottom - gap;
      const availableAbove = triggerRect.top - gap;
      const openUpward =
        availableBelow < estimateActionsMenuHeight && availableAbove > availableBelow;
      const top = openUpward ? triggerRect.top - gap : triggerRect.bottom + gap;

      let left = triggerRect.right - minWidth;
      left = Math.max(viewportPadding, left);
      left = Math.min(left, window.innerWidth - minWidth - viewportPadding);

      setActionsMenuPosition({
        top,
        left,
        minWidth,
        openUpward,
      });
    },
    [closeActionsMenu, estimateActionsMenuHeight]
  );

  const handleToggleActionsMenu = useCallback(
    (userId: string) => {
      if (openActionsUserId === userId) {
        closeActionsMenu();
        return;
      }

      setOpenActionsUserId(userId);
      requestAnimationFrame(() => {
        updateActionsMenuPosition(userId);
      });
    },
    [closeActionsMenu, openActionsUserId, updateActionsMenuPosition]
  );

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target;
      if (!(target instanceof Node)) {
        return;
      }

      if (menuRootRef.current?.contains(target)) {
        return;
      }

      if (triggerRefs.current[openActionsUserId]?.contains(target)) {
        return;
      }

      closeActionsMenu();
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeActionsMenu();
      }
    };

    document.addEventListener("pointerdown", handlePointerDown, true);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("pointerdown", handlePointerDown, true);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeActionsMenu, openActionsUserId]);

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handleViewportChange = () => {
      updateActionsMenuPosition(openActionsUserId);
    };

    window.addEventListener("resize", handleViewportChange);
    window.addEventListener("scroll", handleViewportChange, true);

    return () => {
      window.removeEventListener("resize", handleViewportChange);
      window.removeEventListener("scroll", handleViewportChange, true);
    };
  }, [openActionsUserId, updateActionsMenuPosition]);

  const openActionsUser =
    openActionsUserId === null
      ? null
      : (users.find((candidate) => candidate.userId === openActionsUserId) ?? null);

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    if (!openActionsUser) {
      closeActionsMenu();
    }
  }, [closeActionsMenu, openActionsUser, openActionsUserId]);

  const handleBalanceAdjust = async (userId: string, operation: "credit" | "debit") => {
    const amountRaw = window.prompt(text.usersBalanceAmountPrompt, "100");
    if (!amountRaw) {
      return;
    }

    const amount = Number.parseInt(amountRaw.trim(), 10);
    if (!Number.isFinite(amount) || amount <= 0) {
      setTimeout(() => {
        window.alert(text.usersBalanceInvalidAmount);
      }, 0);
      return;
    }

    const reasonRaw = window.prompt(text.usersBalanceReasonPrompt, text.usersBalanceReasonDefault);
    if (!reasonRaw) {
      return;
    }

    await runAction(
      userId,
      async () => {
        await adjustAdminUserWallet(userId, operation, amount, reasonRaw.trim());
      },
      {
        successMessage: text.walletOperationSaved,
        errorMessage: text.walletOperationError,
      }
    );
  };
  const hero = (
    <AdminPageHero
      eyebrow={text.usersHeroEyebrow}
      title={text.usersTitle}
      description={text.usersHeroDescription}
    />
  );

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        {hero}
        <AdminStateCard
          tone="info"
          title={text.usersTitle}
          description={text.usersLoadingDescription}
        >
          <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
            {Array.from({ length: 6 }).map((_, index) => (
              <div key={index} className={styles.skeletonLine} />
            ))}
          </div>
        </AdminStateCard>
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.page}>
      {hero}
      <AdminCard title={text.usersTitle} description={text.usersCardDescription}>
        {error ? <AdminStateCard tone="danger" className={styles.message} title={error} /> : null}

        {!users.length ? (
          <AdminStateCard
            tone="info"
            className={styles.emptyState}
            title={text.noUsers}
            description={text.usersEmptyDescription}
          />
        ) : null}

        {!!users.length && (
          <div className={`${adminTableStyles.tableWrap} ${styles.tableWrap}`}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.avatarLabel}</th>
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
                      <td data-label={text.avatarLabel}>
                        <UserAvatarView
                          avatar={user.avatar}
                          label={`${text.avatarLabel}: ${user.displayName ?? user.email}`}
                          fallbackLabel={user.displayName ?? user.email}
                        />
                      </td>
                      <td data-label={text.emailLabel}>
                        <Link
                          href={`/${locale}/users/${user.userId}`}
                          className={`${styles.userAnchor} ${styles.userAnchorActive}`}
                        >
                          <span>{user.email}</span>
                        </Link>
                      </td>
                      <td data-label={text.roleLabel}>
                        <div className={styles.roleList}>
                          {user.roles.map((role) => (
                            <AdminBadge
                              key={role}
                              tone={getUserRoleTone(role)}
                              className={styles.rolePill}
                            >
                              {getUserRoleLabel(role, text)}
                            </AdminBadge>
                          ))}
                        </div>
                      </td>
                      <td data-label={text.premiumLabel}>
                        <AdminStatusBadge color={user.isPremium ? "#22c55e" : "#8da1ba"}>
                          {user.isPremium ? text.yesLabel : text.noLabel}
                        </AdminStatusBadge>
                      </td>
                      <td data-label={text.activeLabel}>
                        <AdminStatusBadge color={user.isActive ? "#2dd4bf" : "#f87171"}>
                          {user.isActive ? text.yesLabel : text.noLabel}
                        </AdminStatusBadge>
                      </td>
                      <td data-label={text.actionsLabel} className={styles.actionsCell}>
                        <div className={styles.actions}>
                          <Button
                            variant="secondary"
                            size="sm"
                            className={styles.adminButtonPrimary}
                            disabled={isBusy}
                            onClick={() =>
                              runAction(user.userId, () =>
                                user.isPremium
                                  ? revokePremium(user.userId)
                                  : setPremium(user.userId, true)
                              )
                            }
                          >
                            <DollarIcon className={styles.buttonIcon} />
                            <span>{user.isPremium ? text.removePremium : text.makePremium}</span>
                          </Button>
                          <div className={styles.actionsMenu}>
                            <button
                              type="button"
                              className={styles.actionMenuTrigger}
                              data-menu-open={openActionsUserId === user.userId ? "true" : "false"}
                              aria-label={text.actionsLabel}
                              aria-haspopup="menu"
                              aria-expanded={openActionsUserId === user.userId}
                              ref={(node) => {
                                triggerRefs.current[user.userId] = node;
                              }}
                              onClick={() => handleToggleActionsMenu(user.userId)}
                            >
                              <MoreHorizontalIcon className={styles.buttonIcon} />
                            </button>
                          </div>
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

      {openActionsUser && actionsMenuPosition && typeof window !== "undefined"
        ? createPortal(
            <div
              ref={menuRootRef}
              className={styles.actionMenuPortal}
              style={{
                top: actionsMenuPosition.top,
                left: actionsMenuPosition.left,
                minWidth: actionsMenuPosition.minWidth,
                transform: actionsMenuPosition.openUpward ? "translateY(-100%)" : undefined,
              }}
              role="menu"
              aria-label={text.actionsLabel}
            >
              <div
                className={`${styles.actionMenuList} ${styles.actionMenuListPortal} ${actionsMenuPosition.openUpward ? styles.actionMenuListUpward : ""}`}
              >
                <button
                  type="button"
                  className={styles.actionMenuItem}
                  disabled={busyUserId === openActionsUser.userId}
                  onClick={() => {
                    closeActionsMenu();
                    void runAction(openActionsUser.userId, () =>
                      setActive(openActionsUser.userId, !openActionsUser.isActive)
                    );
                  }}
                >
                  {openActionsUser.isActive ? (
                    <CancelCircleIcon className={styles.buttonIcon} />
                  ) : (
                    <RefreshIcon className={styles.buttonIcon} />
                  )}
                  <span>{openActionsUser.isActive ? text.deactivate : text.activate}</span>
                </button>
                <button
                  type="button"
                  className={styles.actionMenuItem}
                  disabled={busyUserId === openActionsUser.userId}
                  onClick={() => {
                    closeActionsMenu();
                    void handleBalanceAdjust(openActionsUser.userId, "credit");
                  }}
                >
                  <DollarIcon className={styles.buttonIcon} />
                  <span>{text.usersBalanceCredit}</span>
                </button>
                <button
                  type="button"
                  className={styles.actionMenuItem}
                  disabled={busyUserId === openActionsUser.userId}
                  onClick={() => {
                    closeActionsMenu();
                    void handleBalanceAdjust(openActionsUser.userId, "debit");
                  }}
                >
                  <DollarIcon className={styles.buttonIcon} />
                  <span>{text.usersBalanceDebit}</span>
                </button>
                {canManageRoles && (
                  <>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        void runAction(openActionsUser.userId, () =>
                          openActionsUser.roles.includes("Moderator")
                            ? revokeRole(openActionsUser.userId, "Moderator")
                            : assignRole(openActionsUser.userId, "Moderator")
                        );
                      }}
                    >
                      <UsersIcon className={styles.buttonIcon} />
                      <span>
                        {openActionsUser.roles.includes("Moderator")
                          ? text.revokeModerator
                          : text.assignModerator}
                      </span>
                    </button>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        void runAction(openActionsUser.userId, () =>
                          openActionsUser.roles.includes("Admin")
                            ? revokeRole(openActionsUser.userId, "Admin")
                            : assignRole(openActionsUser.userId, "Admin")
                        );
                      }}
                    >
                      <UsersIcon className={styles.buttonIcon} />
                      <span>
                        {openActionsUser.roles.includes("Admin")
                          ? text.revokeAdmin
                          : text.assignAdmin}
                      </span>
                    </button>
                    <button
                      type="button"
                      className={`${styles.actionMenuItem} ${styles.actionMenuItemDanger}`}
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        if (!window.confirm(text.usersDeleteConfirm)) {
                          return;
                        }

                        void runAction(
                          openActionsUser.userId,
                          () => deleteAdminUser(openActionsUser.userId),
                          {
                            successMessage: text.usersDeletedSuccess,
                            errorMessage: text.errorLoadingUsers,
                          }
                        );
                      }}
                    >
                      <CancelCircleIcon className={styles.buttonIcon} />
                      <span>{text.usersDeleteAction}</span>
                    </button>
                  </>
                )}
                <Link
                  href={`/${locale}/users/${openActionsUser.userId}`}
                  className={styles.actionMenuLink}
                  onClick={closeActionsMenu}
                >
                  <span>{text.userDetailOpen}</span>
                </Link>
              </div>
            </div>,
            document.body
          )
        : null}

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </AdminPage>
  );
}
