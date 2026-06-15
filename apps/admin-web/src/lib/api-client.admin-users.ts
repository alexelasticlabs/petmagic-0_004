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
    AdminUserPet,
    AdminUserPetGeneration,
    AdminUserPetPhoto,
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
type AdminUserRoleFilter = AdminAssignableRole | "User";
type AdminUserStatusFilter = "active" | "blocked" | "unconfirmed";

const USER_LIST_MAX_TAKE = 100;
export const USER_SEARCH_MAX_LENGTH = 120;
export const USER_WALLET_REASON_MAX_LENGTH = 240;
const allowedUserRoles: readonly AdminUserRoleFilter[] = ["Admin", "Moderator", "User"];
const allowedUserStatuses: readonly AdminUserStatusFilter[] = ["active", "blocked", "unconfirmed"];
const allowedAssignableRoles: readonly AdminAssignableRole[] = ["Admin", "Moderator"];

function normalizeAllowedValue<const T extends string>(
  value: string | undefined,
  allowedValues: readonly T[]
): T | undefined {
  const normalizedValue = value?.trim();
  if (!normalizedValue) {
    return undefined;
  }

  return allowedValues.find(
    (allowedValue) => allowedValue.toLowerCase() === normalizedValue.toLowerCase()
  );
}

export function normalizeFetchUsersQuery(query: FetchUsersQuery = {}): FetchUsersQuery {
  const search = query.search?.trim().slice(0, USER_SEARCH_MAX_LENGTH) || undefined;
  const role = normalizeAllowedValue(query.role, allowedUserRoles);
  const status = normalizeAllowedValue(query.status, allowedUserStatuses);

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
    role,
    status,
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

  return `/api/admin/users?${params.toString()}`;
}

function assertAssignableRole(role: string): AdminAssignableRole {
  const normalizedRole = normalizeAllowedValue(role, allowedAssignableRoles);
  if (normalizedRole) {
    return normalizedRole;
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

export async function fetchAdminUserPets(
  userId: string,
  signal?: AbortSignal
): Promise<AdminUserPet[]> {
  const encodedUserId = encodePathSegment(userId);
  return apiRequest<AdminUserPet[]>(`/api/admin/users/${encodedUserId}/pets`, {
    method: "GET",
    signal,
  });
}

export async function changeAdminUserPetStatus(
  userId: string,
  petId: string,
  status: "active" | "hidden" | "flagged" | "deleted"
): Promise<AdminUserPet> {
  const encodedUserId = encodePathSegment(userId);
  const encodedPetId = encodePathSegment(petId);
  return apiRequest<AdminUserPet>(
    `/api/admin/users/${encodedUserId}/pets/${encodedPetId}/status`,
    {
      method: "POST",
      body: JSON.stringify({ status }),
    }
  );
}

export async function fetchAdminUserPetPhotos(
  userId: string,
  petId: string,
  signal?: AbortSignal
): Promise<AdminUserPetPhoto[]> {
  const encodedUserId = encodePathSegment(userId);
  const encodedPetId = encodePathSegment(petId);
  return apiRequest<AdminUserPetPhoto[]>(
    `/api/admin/users/${encodedUserId}/pets/${encodedPetId}/photos`,
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchAdminUserPetGenerations(
  userId: string,
  petId: string,
  signal?: AbortSignal
): Promise<AdminUserPetGeneration[]> {
  const encodedUserId = encodePathSegment(userId);
  const encodedPetId = encodePathSegment(petId);
  return apiRequest<AdminUserPetGeneration[]>(
    `/api/admin/users/${encodedUserId}/pets/${encodedPetId}/generations`,
    {
      method: "GET",
      signal,
    }
  );
}

export async function changeAdminUserPetPhotoStatus(
  userId: string,
  petId: string,
  photoId: string,
  status: "active" | "hidden" | "flagged" | "deleted"
): Promise<AdminUserPetPhoto> {
  const encodedUserId = encodePathSegment(userId);
  const encodedPetId = encodePathSegment(petId);
  const encodedPhotoId = encodePathSegment(photoId);
  return apiRequest<AdminUserPetPhoto>(
    `/api/admin/users/${encodedUserId}/pets/${encodedPetId}/photos/${encodedPhotoId}/status`,
    {
      method: "POST",
      body: JSON.stringify({ status }),
    }
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
