"use client";

import Link from "next/link";
import { createPortal } from "react-dom";
import type { Dispatch, MutableRefObject, SetStateAction } from "react";

import { CancelCircleIcon, DollarIcon, UsersIcon } from "@/components/admin/admin-icons";
import { Button } from "@/components/ui/button";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import styles from "@/components/users-management-page.module.css";
import { USER_WALLET_REASON_MAX_LENGTH, type UserListItem } from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";
import type {
  ActionsMenuPosition,
  WalletDialogState,
} from "@/components/users-management-page.types";

type UsersManagementActionsMenuProps = {
  actionsMenuPosition: ActionsMenuPosition;
  busyUserId: string | null;
  canManageRoles: boolean;
  cannotRevokeLastAdmin: boolean;
  closeActionsMenu: () => void;
  isUserActionLocked: boolean;
  locale: Locale;
  menuRootRef: MutableRefObject<HTMLDivElement | null>;
  openActionsUser: UserListItem;
  openWalletDialog: (userId: string, operation: "credit" | "debit") => void;
  requestDeleteUser: (user: UserListItem, afterSuccess?: () => void) => void;
  requestRoleChange: (user: UserListItem, role: "Admin" | "Moderator") => void;
  setSelectedUserId: (userId: string) => void;
  text: Dictionary;
  ui: UsersManagementPageText;
};

export function UsersManagementActionsMenu({
  actionsMenuPosition,
  busyUserId,
  canManageRoles,
  cannotRevokeLastAdmin,
  closeActionsMenu,
  isUserActionLocked,
  locale,
  menuRootRef,
  openActionsUser,
  openWalletDialog,
  requestDeleteUser,
  requestRoleChange,
  setSelectedUserId,
  text,
  ui,
}: UsersManagementActionsMenuProps) {
  if (typeof window === "undefined") {
    return null;
  }

  return createPortal(
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
      aria-label={ui.menuLabel}
    >
      <div
        className={`${styles.actionMenuList} ${actionsMenuPosition.openUpward ? styles.actionMenuListUpward : ""}`}
      >
        <button
          type="button"
          className={styles.actionMenuItem}
          disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
          onClick={() => {
            closeActionsMenu();
            setSelectedUserId(openActionsUser.userId);
          }}
        >
          <UsersIcon className={styles.buttonIcon} />
          <span>{ui.openCard}</span>
        </button>
        {canManageRoles && (
          <>
            <button
              type="button"
              className={styles.actionMenuItem}
              disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
              onClick={() => {
                openWalletDialog(openActionsUser.userId, "credit");
              }}
            >
              <DollarIcon className={styles.buttonIcon} />
              <span>{text.usersBalanceCredit}</span>
            </button>
            <button
              type="button"
              className={styles.actionMenuItem}
              disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
              onClick={() => {
                openWalletDialog(openActionsUser.userId, "debit");
              }}
            >
              <DollarIcon className={styles.buttonIcon} />
              <span>{text.usersBalanceDebit}</span>
            </button>
            <button
              type="button"
              className={styles.actionMenuItem}
              disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
              onClick={() => {
                requestRoleChange(openActionsUser, "Moderator");
              }}
            >
              <UsersIcon className={styles.buttonIcon} />
              <span>
                {openActionsUser.roles.includes("Moderator")
                  ? text.revokeModerator
                  : text.assignModerator}
              </span>
            </button>
            {/* prettier-ignore */}
            <button
              type="button"
              className={styles.actionMenuItem}
              disabled={
                        isUserActionLocked ||
                        busyUserId === openActionsUser.userId ||
                        cannotRevokeLastAdmin
              }
              title={cannotRevokeLastAdmin ? ui.lastAdminProtected : undefined}
              onClick={() => {
                requestRoleChange(openActionsUser, "Admin");
              }}
            >
              <UsersIcon className={styles.buttonIcon} />
              <span>
                {openActionsUser.roles.includes("Admin") ? text.revokeAdmin : text.assignAdmin}
              </span>
            </button>
            <button
              type="button"
              className={`${styles.actionMenuItem} ${styles.actionMenuItemDanger}`}
              disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
              onClick={() => {
                requestDeleteUser(openActionsUser);
              }}
            >
              <CancelCircleIcon className={styles.buttonIcon} />
              <span>{text.usersDeleteAction}</span>
            </button>
          </>
        )}
        <Link
          href={`/${locale}/users/${encodeURIComponent(openActionsUser.userId)}`}
          className={`${styles.actionMenuLink}${
            isUserActionLocked || busyUserId === openActionsUser.userId
              ? ` ${styles.actionMenuLinkDisabled}`
              : ""
          }`}
          aria-disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
          tabIndex={isUserActionLocked || busyUserId === openActionsUser.userId ? -1 : undefined}
          onClick={(event) => {
            // prettier-ignore
            if (isUserActionLocked || busyUserId === openActionsUser.userId) {
              event.preventDefault();
                      return;
            }

            closeActionsMenu();
          }}
        >
          <span>{ui.openCard}</span>
        </Link>
      </div>
    </div>,
    document.body
  );
}

type UsersManagementWalletDialogProps = {
  closeWalletDialog: () => void;
  setWalletDialog: Dispatch<SetStateAction<WalletDialogState | null>>;
  submitWalletDialog: () => void;
  ui: UsersManagementPageText;
  walletDialog: WalletDialogState;
  walletDialogErrorId: string;
  walletDialogSubmitting: boolean;
  walletDialogTitleId: string;
};

export function UsersManagementWalletDialog({
  closeWalletDialog,
  setWalletDialog,
  submitWalletDialog,
  ui,
  walletDialog,
  walletDialogErrorId,
  walletDialogSubmitting,
  walletDialogTitleId,
}: UsersManagementWalletDialogProps) {
  if (typeof window === "undefined") {
    return null;
  }

  return createPortal(
    <div className={styles.walletDialogBackdrop} onClick={closeWalletDialog}>
      <div
        className={styles.walletDialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby={walletDialogTitleId}
        aria-describedby={walletDialog.error ? walletDialogErrorId : undefined}
        onClick={(event) => event.stopPropagation()}
      >
        <h3 id={walletDialogTitleId} className={styles.walletDialogTitle}>
          {walletDialog.operation === "credit"
            ? ui.walletDialogTitleCredit
            : ui.walletDialogTitleDebit}
        </h3>
        <label className={styles.walletField}>
          <span>{ui.walletAmountLabel}</span>
          <input
            className={styles.walletInput}
            inputMode="numeric"
            value={walletDialog.amount}
            onChange={(event) =>
              setWalletDialog((current) =>
                current
                  ? {
                      ...current,
                      amount: event.target.value.replace(/\D+/g, "").slice(0, 8),
                      error: null,
                    }
                  : current
              )
            }
            autoFocus
            maxLength={8}
            disabled={walletDialogSubmitting}
          />
        </label>
        <label className={styles.walletField}>
          <span>{ui.walletReasonLabel}</span>
          <textarea
            className={styles.walletTextarea}
            value={walletDialog.reason}
            onChange={(event) =>
              setWalletDialog((current) =>
                current
                  ? {
                      ...current,
                      reason: event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH),
                      error: null,
                    }
                  : current
              )
            }
            rows={3}
            maxLength={USER_WALLET_REASON_MAX_LENGTH}
            disabled={walletDialogSubmitting}
          />
        </label>
        {walletDialog.error ? (
          <p id={walletDialogErrorId} className={styles.walletError} role="alert">
            {walletDialog.error}
          </p>
        ) : null}
        <div className={styles.walletActions}>
          {/* prettier-ignore */}
          <Button
            variant="ghost"
                    size="sm"
                    onClick={closeWalletDialog}
                    disabled={walletDialogSubmitting}
          >
            {ui.walletCancel}
          </Button>
          {/* prettier-ignore */}
          <Button
            variant="secondary"
                    size="sm"
                    onClick={() => {
                      void submitWalletDialog();
                    }}
                    disabled={
              walletDialogSubmitting || !walletDialog.amount.trim() || !walletDialog.reason.trim()
            }
          >
            {ui.walletSubmit}
          </Button>
        </div>
      </div>
    </div>,
    document.body
  );
}
