import type { AdminTone } from "@/components/admin/admin-primitives";
import type {
  AccountStatus,
  RangeDays,
  UserRoleText,
} from "@/components/users-management-page.types";
import type { AdminUserDashboardMetrics, UserListItem } from "@/lib/api-client";
import { getAdminUserDisplayName, sanitizeSensitiveText } from "@/lib/sensitive-display";

export const accountStatusColors: Record<AccountStatus, string> = {
  active: "var(--success)",
  blocked: "var(--danger)",
  unconfirmed: "var(--warning)",
};

export const premiumStatusColors = {
  premium: "var(--success)",
  free: "var(--text-muted)",
};

export function getUserRoleLabel(role: string, text: UserRoleText) {
  return role === "Admin"
    ? text.userRoleAdmin
    : role === "Moderator"
      ? text.userRoleModerator
      : role === "User"
        ? text.userRoleUser
        : sanitizeSensitiveText(role, 32);
}

export function getUserRoleTone(role: string): AdminTone {
  if (role === "Admin") {
    return "primary";
  }

  if (role === "Moderator") {
    return "info";
  }

  return "neutral";
}

export function getUserAvatarLabel(
  user: Pick<UserListItem, "displayName" | "email" | "userId">
): string {
  return sanitizeSensitiveText(getAdminUserDisplayName(user), 96);
}

export function getAccountStatus(user: UserListItem): AccountStatus {
  if (!user.isActive) {
    return "blocked";
  }

  if (!user.emailConfirmed) {
    return "unconfirmed";
  }

  return "active";
}

export function formatMetricCount(value: number | null | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? String(Math.max(0, value)) : "—";
}

export function getNewUsersCountForRange(
  metrics: AdminUserDashboardMetrics | null,
  rangeDays: RangeDays
): number | null {
  if (!metrics) {
    return null;
  }

  if (rangeDays === 7) {
    return metrics.newUsersLast7Days;
  }

  if (rangeDays === 30) {
    return metrics.newUsersLast30Days;
  }

  return metrics.newUsersLast90Days;
}
