import type { UsersManagementPageText } from "@/components/users-management-page.content";
import type {
  AdminEconomyUserSubscriptionSummary,
  AdminUserAnalytics,
  UserListItem,
} from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

export type UsersManagementPageProps = {
  locale: Locale;
};

export type ActionsMenuPosition = {
  top: number;
  left: number;
  minWidth: number;
  openUpward: boolean;
};

export type AccountStatus = "active" | "blocked" | "unconfirmed";

export type WalletDialogState = {
  userId: string;
  operation: "credit" | "debit";
  amount: string;
  reason: string;
  error: string | null;
};

export type ConfirmationDialogState = {
  userId: string;
  title: string;
  description: string;
  confirmLabel: string;
  successMessage?: string;
  errorMessage?: string;
  tone?: "danger" | "primary";
  action: () => Promise<void>;
  afterSuccess?: () => void;
};

export type RangeDays = 7 | 30 | 90;

export type RoleFilter = "all" | "Admin" | "Moderator" | "User";
export type PremiumFilter = "all" | "premium" | "free";
export type ActivityFilter = "all" | "active" | "blocked";
export type StatusFilter = "all" | "active" | "blocked" | "unconfirmed";
export type UserSortMode =
  "created_desc" | "created_asc" | "last_activity_desc" | "last_activity_asc";

export type UserRoleText = Pick<Dictionary, "userRoleAdmin" | "userRoleModerator" | "userRoleUser">;

export type UsersManagementSidePanelProps = {
  busyUserId: string | null;
  canManageRoles: boolean;
  closePanel: () => void;
  isUserActionLocked: boolean;
  locale: Locale;
  requestActiveChange: (user: UserListItem) => void;
  requestDeleteUser: (user: UserListItem, afterSuccess?: () => void) => void;
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
  text: Dictionary;
  ui: UsersManagementPageText;
};
