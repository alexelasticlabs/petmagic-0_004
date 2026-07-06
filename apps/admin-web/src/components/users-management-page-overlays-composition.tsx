"use client";

import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Toast } from "@/components/ui/toast";
import {
  UsersManagementActionsMenu,
  UsersManagementWalletDialog,
} from "@/components/users-management-page-overlays";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import type {
  ActionsMenuPosition,
  ConfirmationDialogState,
  WalletDialogState,
} from "@/components/users-management-page.types";
import { UsersManagementSidePanel } from "@/components/users-management-side-panel";
import type {
  AdminEconomyUserSubscriptionSummary,
  AdminUserAnalytics,
  UserListItem,
} from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

import type { Dispatch, MutableRefObject, SetStateAction } from "react";

type UsersManagementPageOverlaysProps = {
  actionsMenuPosition: ActionsMenuPosition | null;
  busyUserId: string | null;
  canManageRoles: boolean;
  cannotRevokeLastAdmin: boolean;
  closeActionsMenu: () => void;
  closeConfirmationDialog: () => void;
  closePanel: () => void;
  closeWalletDialog: () => void;
  confirmationDialog: ConfirmationDialogState | null;
  confirmationSubmitting: boolean;
  isUserActionLocked: boolean;
  locale: Locale;
  menuRootRef: MutableRefObject<HTMLDivElement | null>;
  openActionsUser: UserListItem | null;
  openWalletDialog: (userId: string, operation: "credit" | "debit") => void;
  requestActiveChange: (user: UserListItem) => void;
  requestDeleteUser: (user: UserListItem, afterSuccess?: () => void) => void;
  requestRoleChange: (user: UserListItem, role: "Admin" | "Moderator") => void;
  requestSelectedUserProfileRetry: () => void;
  selectedSubscription: AdminEconomyUserSubscriptionSummary | null;
  selectedUser: UserListItem | null;
  selectedUserAnalytics: AdminUserAnalytics | null;
  selectedUserId: string | null;
  selectedUserProfile: {
    error: unknown;
    hasError: boolean;
    isFetching: boolean;
  };
  selectedUserSupportTickets: Array<{
    conversationId: string;
    lastMessagePreview?: string | null;
    status: string;
    updatedAtUtc: string | null;
  }>;
  setSelectedUserId: Dispatch<SetStateAction<string | null>>;
  setWalletDialog: Dispatch<SetStateAction<WalletDialogState | null>>;
  submitConfirmationDialog: () => Promise<void>;
  submitWalletDialog: () => Promise<void>;
  text: Dictionary;
  toast: { message: string; type: "success" | "error" } | null;
  ui: UsersManagementPageText;
  walletDialog: WalletDialogState | null;
  walletDialogErrorId: string;
  walletDialogSubmitting: boolean;
  walletDialogTitleId: string;
};

export function UsersManagementPageOverlays({
  actionsMenuPosition,
  busyUserId,
  canManageRoles,
  cannotRevokeLastAdmin,
  closeActionsMenu,
  closeConfirmationDialog,
  closePanel,
  closeWalletDialog,
  confirmationDialog,
  confirmationSubmitting,
  isUserActionLocked,
  locale,
  menuRootRef,
  openActionsUser,
  openWalletDialog,
  requestActiveChange,
  requestDeleteUser,
  requestRoleChange,
  requestSelectedUserProfileRetry,
  selectedSubscription,
  selectedUser,
  selectedUserAnalytics,
  selectedUserId,
  selectedUserProfile,
  selectedUserSupportTickets,
  setSelectedUserId,
  setWalletDialog,
  submitConfirmationDialog,
  submitWalletDialog,
  text,
  toast,
  ui,
  walletDialog,
  walletDialogErrorId,
  walletDialogSubmitting,
  walletDialogTitleId,
}: UsersManagementPageOverlaysProps) {
  return (
    <>
      {openActionsUser && actionsMenuPosition ? (
        <UsersManagementActionsMenu
          actionsMenuPosition={actionsMenuPosition}
          busyUserId={busyUserId}
          canManageRoles={canManageRoles}
          cannotRevokeLastAdmin={cannotRevokeLastAdmin}
          closeActionsMenu={closeActionsMenu}
          isUserActionLocked={isUserActionLocked}
          locale={locale}
          menuRootRef={menuRootRef}
          openActionsUser={openActionsUser}
          openWalletDialog={openWalletDialog}
          requestDeleteUser={requestDeleteUser}
          requestRoleChange={requestRoleChange}
          setSelectedUserId={setSelectedUserId}
          text={text}
          ui={ui}
        />
      ) : null}

      <ConfirmationDialog
        open={confirmationDialog !== null}
        title={confirmationDialog?.title ?? ""}
        description={confirmationDialog?.description ?? ""}
        confirmLabel={confirmationDialog?.confirmLabel ?? ui.confirmAction}
        cancelLabel={ui.confirmCancel}
        isSubmitting={confirmationSubmitting}
        tone={confirmationDialog?.tone ?? "danger"}
        onCancel={closeConfirmationDialog}
        onConfirm={() => {
          void submitConfirmationDialog();
        }}
      />

      {walletDialog ? (
        <UsersManagementWalletDialog
          closeWalletDialog={closeWalletDialog}
          setWalletDialog={setWalletDialog}
          submitWalletDialog={() => {
            void submitWalletDialog();
          }}
          ui={ui}
          walletDialog={walletDialog}
          walletDialogErrorId={walletDialogErrorId}
          walletDialogSubmitting={walletDialogSubmitting}
          walletDialogTitleId={walletDialogTitleId}
        />
      ) : null}

      <UsersManagementSidePanel
        busyUserId={busyUserId}
        canManageRoles={canManageRoles}
        closePanel={closePanel}
        isUserActionLocked={isUserActionLocked}
        locale={locale}
        requestActiveChange={requestActiveChange}
        requestDeleteUser={requestDeleteUser}
        requestSelectedUserProfileRetry={requestSelectedUserProfileRetry}
        selectedSubscription={selectedSubscription}
        selectedUser={selectedUser}
        selectedUserAnalytics={selectedUserAnalytics}
        selectedUserId={selectedUserId}
        selectedUserProfile={selectedUserProfile}
        selectedUserSupportTickets={selectedUserSupportTickets}
        text={text}
        ui={ui}
      />

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </>
  );
}
