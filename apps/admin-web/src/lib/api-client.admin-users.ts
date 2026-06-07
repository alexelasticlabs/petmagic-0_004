import {
    apiRequest,
    cachedAdminUserAnalytics,
    cachedAdminUserDetails,
    cachedGet,
    cachedUsersLists,
    encodePathSegment,
} from "./api-client.core";

import type {
    AdminUserAnalytics,
    AdminUserDashboardMetrics,
    AdminUserDetail,
    AdminUserWalletOperation,
    UserListPage,
} from "./api-client.types";

export type FetchUsersQuery = {
  skip?: number;
  take?: number;
  search?: string;
  role?: string;
  status?: string;
  isPremium?: boolean;
};

type AdminAssignableRole = "Admin" | "Moderator";

const USER_LIST_MAX_TAKE = 100;
export const USER_SEARCH_MAX_LENGTH = 120;
export const USER_WALLET_REASON_MAX_LENGTH = 240;
const allowedUserRoles = new Set(["Admin", "Moderator", "User"]);
const allowedUserStatuses = new Set(["active", "blocked", "unconfirmed"]);
const allowedAssignableRoles = new Set<AdminAssignableRole>(["Admin", "Moderator"]);

export function normalizeFetchUsersQuery(query: FetchUsersQuery = {}): FetchUsersQuery {
  const search = query.search?.trim().slice(0, USER_SEARCH_MAX_LENGTH) || undefined;
  const role = query.role?.trim();
  const status = query.status?.trim();

  return {
    skip:
      typeof query.skip === "number" && Number.isFinite(query.skip)
        ? Math.max(0, Math.floor(query.skip))
        : 0,
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(Math.floor(query.take), USER_LIST_MAX_TAKE)
        : USER_LIST_MAX_TAKE,
    search,
    role: role && allowedUserRoles.has(role) ? role : undefined,
    status: status && allowedUserStatuses.has(status) ? status : undefined,
    isPremium: typeof query.isPremium === "boolean" ? query.isPremium : undefined,
  };
}

function getUsersCacheKey(query: FetchUsersQuery): string {
  const normalizedQuery = normalizeFetchUsersQuery(query);
  return JSON.stringify({
    skip: normalizedQuery.skip ?? 0,
    take: normalizedQuery.take ?? USER_LIST_MAX_TAKE,
    search: normalizedQuery.search ?? null,
    role: normalizedQuery.role ?? null,
    status: normalizedQuery.status ?? null,
    isPremium: normalizedQuery.isPremium ?? null,
  });
}

function buildUsersPath(query: FetchUsersQuery): string {
  const normalizedQuery = normalizeFetchUsersQuery(query);
  const params = new URLSearchParams();
  params.set("skip", String(normalizedQuery.skip ?? 0));
  params.set("take", String(normalizedQuery.take ?? USER_LIST_MAX_TAKE));

  if (normalizedQuery.search) {
    params.set("search", normalizedQuery.search);
  }

  if (normalizedQuery.role) {
    params.set("role", normalizedQuery.role);
  }

  if (normalizedQuery.status) {
    params.set("status", normalizedQuery.status);
  }

  if (typeof normalizedQuery.isPremium === "boolean") {
    params.set("isPremium", String(normalizedQuery.isPremium));
  }

  return `/api/admin/users/?${params.toString()}`;
}

function assertAssignableRole(role: string): AdminAssignableRole {
  const normalizedRole = role.trim();
  if (allowedAssignableRoles.has(normalizedRole as AdminAssignableRole)) {
    return normalizedRole as AdminAssignableRole;
  }

  throw new Error("Invalid admin role.");
}

export async function fetchUsers(
  query: FetchUsersQuery = {},
  signal?: AbortSignal
): Promise<UserListPage> {
  const cacheKey = `users:${getUsersCacheKey(query)}`;
  return cachedGet(
    cacheKey,
    cachedUsersLists,
    async () => {
      const response = await apiRequest<UserListPage>(buildUsersPath(query), {
        method: "GET",
        signal,
      });

      return response;
    },
    signal
  );
}

export async function fetchAdminUserDashboardMetrics(
  signal?: AbortSignal
): Promise<AdminUserDashboardMetrics> {
  return apiRequest<AdminUserDashboardMetrics>("/api/admin/users/dashboard/metrics", {
    method: "GET",
    signal,
  });
}

export async function fetchAdminUser(
  userId: string,
  signal?: AbortSignal
): Promise<AdminUserDetail> {
  const encodedUserId = encodePathSegment(userId);
  return cachedGet(
    `admin-user:${userId}`,
    cachedAdminUserDetails,
    () =>
      apiRequest<AdminUserDetail>(`/api/admin/users/${encodedUserId}`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function fetchAdminUserAnalytics(
  userId: string,
  signal?: AbortSignal
): Promise<AdminUserAnalytics> {
  const encodedUserId = encodePathSegment(userId);
  return cachedGet(
    `admin-user-analytics:${userId}`,
    cachedAdminUserAnalytics,
    () =>
      apiRequest<AdminUserAnalytics>(`/api/admin/users/${encodedUserId}/analytics`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function adjustAdminUserWallet(
  userId: string,
  operation: "credit" | "debit",
  amount: number,
  reason: string
): Promise<AdminUserWalletOperation> {
  const encodedUserId = encodePathSegment(userId);
  const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);
  const result = await apiRequest<AdminUserWalletOperation>(
    `/api/admin/users/${encodedUserId}/wallet`,
    {
      method: "POST",
      body: JSON.stringify({ operation, amount, reason: normalizedReason }),
    }
  );

  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
  return result;
}

export async function assignRole(userId: string, role: string): Promise<void> {
  const normalizedRole = assertAssignableRole(role);
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/role`, {
    method: "PUT",
    body: JSON.stringify({ role: normalizedRole }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function revokeRole(userId: string, role: string): Promise<void> {
  const normalizedRole = assertAssignableRole(role);
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/role`, {
    method: "DELETE",
    body: JSON.stringify({ role: normalizedRole }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setPremium(userId: string, isPremium: boolean): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/premium`, {
    method: "PUT",
    body: JSON.stringify({ isPremium }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function revokePremium(userId: string): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/economy/users/${encodedUserId}/premium/revoke`, {
    method: "PUT",
    body: JSON.stringify({ paymentProvider: "stripe" }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setActive(userId: string, isActive: boolean): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/active`, {
    method: "PUT",
    body: JSON.stringify({ isActive }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function deleteAdminUser(userId: string): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}`, {
    method: "DELETE",
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}
