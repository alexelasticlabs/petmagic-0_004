import type { AdminTone } from "@/components/admin/admin-primitives";
import type { AdminUserAnalytics, AdminUserDashboardMetrics, UserListItem } from "@/lib/api-client";
import { getAdminUserDisplayName, sanitizeSensitiveText } from "@/lib/sensitive-display";

import type {
  AccountStatus,
  RangeDays,
  UserRoleText,
} from "@/components/users-management-page.types";

const ROW_ENRICHMENT_CONCURRENCY = 4;

export const accountStatusColors: Record<AccountStatus, string> = {
  active: "var(--success)",
  blocked: "var(--danger)",
  unconfirmed: "var(--warning)",
};

export const premiumStatusColors = {
  premium: "var(--success)",
  free: "var(--text-muted)",
};

export function throwIfAborted(signal?: AbortSignal): void {
  if (signal?.aborted) {
    throw new DOMException("Aborted", "AbortError");
  }
}

export function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === "AbortError";
}

export function getUsersPageErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export async function fetchUserRowEnrichment<TValue>(
  userIds: readonly string[],
  signal: AbortSignal | undefined,
  load: (userId: string, signal?: AbortSignal) => Promise<TValue>
): Promise<Map<string, TValue>> {
  const results = new Map<string, TValue>();
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < userIds.length) {
      throwIfAborted(signal);
      const userId = userIds[nextIndex];
      nextIndex += 1;

      try {
        const value = await load(userId, signal);
        results.set(userId, value);
      } catch (error) {
        if (signal?.aborted || isAbortError(error)) {
          throw error;
        }
      }
    }
  }

  const workerCount = Math.min(ROW_ENRICHMENT_CONCURRENCY, userIds.length);
  await Promise.all(Array.from({ length: workerCount }, () => worker()));
  return results;
}

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
    return "danger";
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

export type UsersPageAnalyticsByUserId = Map<string, AdminUserAnalytics>;
