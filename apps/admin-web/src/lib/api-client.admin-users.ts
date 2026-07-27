import {
  apiRequest,
  cachedAdminUserAnalytics,
  cachedAdminUserDetails,
  cachedGet,
  cachedUsersLists,
  encodePathSegment,
  invalidateCachedGetNamespaces,
} from "./api-client.core";
import { adminCancelPremiumSubscription } from "./api-client.economy";

import type {
  AdminEconomyUserSubscriptionSummary,
  AdminEmailBroadcastAccepted,
  AdminEmailBroadcastDetail,
  AdminEmailBroadcastRetryResult,
  AdminEmailBroadcastsPage,
  AdminEmailBroadcastStatus,
  AdminUserAnalytics,
  AdminUserDashboardMetrics,
  AdminUserDetail,
  AdminUserPet,
  AdminUserPetGeneration,
  AdminUserPetPhoto,
  AdminUserSessionRevokeResponse,
  AdminUserSessions,
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
  sort?: string;
};

export type AdminUserSort =
  "created_desc" | "created_asc" | "last_activity_desc" | "last_activity_asc";
export type AdminBulkEmailAudience = "all-active" | "premium" | "selected";
export type AdminBulkEmailRequest = {
  audience: AdminBulkEmailAudience;
  subject: string;
  body: string;
  userIds?: readonly string[];
};
export type AdminEmailBroadcastsQuery = {
  skip?: number;
  take?: number;
  status?: AdminEmailBroadcastStatus | "all";
};

type AdminAssignableRole = "Admin" | "Moderator";
type AdminUserRoleFilter = AdminAssignableRole | "User";
type AdminUserStatusFilter = "active" | "blocked" | "unconfirmed";

const USER_LIST_MAX_TAKE = 100;
const EMAIL_BROADCASTS_DEFAULT_TAKE = 10;
const EMAIL_BROADCASTS_MAX_TAKE = 100;
export const USER_SEARCH_MAX_LENGTH = 120;
export const USER_WALLET_REASON_MAX_LENGTH = 120;
export const USER_SESSION_REVOKE_REASON_MAX_LENGTH = 240;
export const ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH = 200;
export const ADMIN_BULK_EMAIL_BODY_MAX_LENGTH = 10_000;
const allowedBulkEmailAudiences: readonly AdminBulkEmailAudience[] = [
  "all-active",
  "premium",
  "selected",
];
const allowedEmailBroadcastStatuses: readonly AdminEmailBroadcastStatus[] = [
  "legacy",
  "queued",
  "processing",
  "completed",
  "partially-failed",
  "failed",
];
const allowedUserRoles: readonly AdminUserRoleFilter[] = ["Admin", "Moderator", "User"];
const allowedUserStatuses: readonly AdminUserStatusFilter[] = ["active", "blocked", "unconfirmed"];
const allowedUserSorts: readonly AdminUserSort[] = [
  "created_desc",
  "created_asc",
  "last_activity_desc",
  "last_activity_asc",
];
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
  const sort = normalizeAllowedValue(query.sort, allowedUserSorts);

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
    sort,
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
    sort: normalizedQuery.sort ?? null,
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

  if (normalizedQuery.sort) {
    params.set("sort", normalizedQuery.sort);
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

export function normalizeAdminBulkEmailRequest(
  request: AdminBulkEmailRequest
): Required<AdminBulkEmailRequest> {
  const audience = normalizeAllowedValue(request.audience, allowedBulkEmailAudiences);
  const subject = request.subject.trim();
  const body = request.body.trim();
  const userIds = [
    ...new Set((request.userIds ?? []).map((userId) => userId.trim()).filter(Boolean)),
  ];

  if (!audience) {
    throw new Error("Invalid bulk email audience.");
  }

  if (!subject || subject.length > ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH) {
    throw new Error("Invalid bulk email subject.");
  }

  if (!body || body.length > ADMIN_BULK_EMAIL_BODY_MAX_LENGTH) {
    throw new Error("Invalid bulk email body.");
  }

  if (audience === "selected" && userIds.length === 0) {
    throw new Error("Selected bulk email audience requires at least one user.");
  }

  return {
    audience,
    subject,
    body,
    userIds: audience === "selected" ? userIds : [],
  };
}

export function normalizeAdminEmailBroadcastsQuery(
  query: AdminEmailBroadcastsQuery = {}
): AdminEmailBroadcastsQuery {
  const status =
    query.status === "all"
      ? undefined
      : normalizeAllowedValue(query.status, allowedEmailBroadcastStatuses);

  return {
    skip:
      typeof query.skip === "number" && Number.isFinite(query.skip)
        ? Math.max(0, Math.floor(query.skip))
        : 0,
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(Math.floor(query.take), EMAIL_BROADCASTS_MAX_TAKE)
        : EMAIL_BROADCASTS_DEFAULT_TAKE,
    status,
  };
}

function clearAdminUserCaches(userId: string): void {
  invalidateCachedGetNamespaces(["users", "admin-user", "admin-user-analytics"]);
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
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

export async function queueAdminBulkEmail(
  request: AdminBulkEmailRequest,
  idempotencyKey?: string
): Promise<AdminEmailBroadcastAccepted> {
  const payload = normalizeAdminBulkEmailRequest(request);
  const normalizedIdempotencyKey = idempotencyKey?.trim();
  return apiRequest<AdminEmailBroadcastAccepted>("/api/admin/users/emails", {
    method: "POST",
    headers: normalizedIdempotencyKey ? { "Idempotency-Key": normalizedIdempotencyKey } : undefined,
    body: JSON.stringify(payload),
  });
}

export async function fetchAdminEmailBroadcasts(
  query: AdminEmailBroadcastsQuery = {},
  signal?: AbortSignal
): Promise<AdminEmailBroadcastsPage> {
  const normalizedQuery = normalizeAdminEmailBroadcastsQuery(query);
  const params = new URLSearchParams({
    skip: String(normalizedQuery.skip ?? 0),
    take: String(normalizedQuery.take ?? EMAIL_BROADCASTS_DEFAULT_TAKE),
  });
  if (normalizedQuery.status) {
    params.set("status", normalizedQuery.status);
  }

  return apiRequest<AdminEmailBroadcastsPage>(
    `/api/admin/users/email-broadcasts?${params.toString()}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEmailBroadcast(
  broadcastId: string,
  signal?: AbortSignal
): Promise<AdminEmailBroadcastDetail> {
  const encodedBroadcastId = encodePathSegment(broadcastId);
  return apiRequest<AdminEmailBroadcastDetail>(
    `/api/admin/users/email-broadcasts/${encodedBroadcastId}`,
    { method: "GET", signal }
  );
}

export async function retryFailedAdminEmailBroadcast(
  broadcastId: string
): Promise<AdminEmailBroadcastRetryResult> {
  const encodedBroadcastId = encodePathSegment(broadcastId);
  return apiRequest<AdminEmailBroadcastRetryResult>(
    `/api/admin/users/email-broadcasts/${encodedBroadcastId}/retry-failed`,
    { method: "POST" }
  );
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

export async function fetchAdminUserSessions(
  userId: string,
  signal?: AbortSignal
): Promise<AdminUserSessions> {
  const encodedUserId = encodePathSegment(userId);
  return apiRequest<AdminUserSessions>(`/api/admin/users/${encodedUserId}/sessions`, {
    method: "GET",
    signal,
  });
}

function normalizeAdminUserSessionRevokeInput(reason: string, idempotencyKey: string) {
  const normalizedReason = reason.trim().slice(0, USER_SESSION_REVOKE_REASON_MAX_LENGTH);
  const normalizedIdempotencyKey = idempotencyKey.trim().slice(0, 256);
  if (!normalizedReason) {
    throw new Error("Session revocation reason is required.");
  }
  if (!normalizedIdempotencyKey) {
    throw new Error("Session revocation idempotency key is required.");
  }

  return { reason: normalizedReason, idempotencyKey: normalizedIdempotencyKey };
}

export async function revokeAdminUserSession(
  userId: string,
  sessionId: string,
  reason: string,
  idempotencyKey: string
): Promise<AdminUserSessionRevokeResponse> {
  const encodedUserId = encodePathSegment(userId);
  const encodedSessionId = encodePathSegment(sessionId);
  const normalized = normalizeAdminUserSessionRevokeInput(reason, idempotencyKey);
  return apiRequest<AdminUserSessionRevokeResponse>(
    `/api/admin/users/${encodedUserId}/sessions/${encodedSessionId}/revoke`,
    {
      method: "POST",
      headers: { "Idempotency-Key": normalized.idempotencyKey },
      body: JSON.stringify({ reason: normalized.reason }),
    }
  );
}

export async function revokeAllAdminUserSessions(
  userId: string,
  reason: string,
  idempotencyKey: string
): Promise<AdminUserSessionRevokeResponse> {
  const encodedUserId = encodePathSegment(userId);
  const normalized = normalizeAdminUserSessionRevokeInput(reason, idempotencyKey);
  return apiRequest<AdminUserSessionRevokeResponse>(
    `/api/admin/users/${encodedUserId}/sessions/revoke-all`,
    {
      method: "POST",
      headers: { "Idempotency-Key": normalized.idempotencyKey },
      body: JSON.stringify({ reason: normalized.reason }),
    }
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
  return apiRequest<AdminUserPet>(`/api/admin/users/${encodedUserId}/pets/${encodedPetId}/status`, {
    method: "POST",
    body: JSON.stringify({ status }),
  });
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
  reason: string,
  idempotencyKey?: string
): Promise<AdminUserWalletOperation> {
  const encodedUserId = encodePathSegment(userId);
  const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);
  const normalizedIdempotencyKey = idempotencyKey?.trim();
  const result = await apiRequest<AdminUserWalletOperation>(
    `/api/admin/users/${encodedUserId}/wallet`,
    {
      method: "POST",
      headers: normalizedIdempotencyKey
        ? { "Idempotency-Key": normalizedIdempotencyKey }
        : undefined,
      body: JSON.stringify({ operation, amount, reason: normalizedReason }),
    }
  );

  clearAdminUserCaches(userId);
  return result;
}

export async function assignRole(userId: string, role: string): Promise<void> {
  const normalizedRole = assertAssignableRole(role);
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/role`, {
    method: "PUT",
    body: JSON.stringify({ role: normalizedRole }),
  });
  clearAdminUserCaches(userId);
}

export async function revokeRole(userId: string, role: string): Promise<void> {
  const normalizedRole = assertAssignableRole(role);
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/role`, {
    method: "DELETE",
    body: JSON.stringify({ role: normalizedRole }),
  });
  clearAdminUserCaches(userId);
}

export async function revokePremium(
  userId: string,
  paymentProvider: string,
  reason: string
): Promise<AdminEconomyUserSubscriptionSummary> {
  const normalizedPaymentProvider = paymentProvider.trim().toLowerCase();
  if (normalizedPaymentProvider !== "stripe") {
    throw new Error("Admin Premium revocation is supported only for Stripe subscriptions.");
  }

  const summary = await adminCancelPremiumSubscription(userId, normalizedPaymentProvider, reason);
  clearAdminUserCaches(userId);
  return summary;
}

export async function setActive(userId: string, isActive: boolean): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}/active`, {
    method: "PUT",
    body: JSON.stringify({ isActive }),
  });
  clearAdminUserCaches(userId);
}

export async function deleteAdminUser(userId: string): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/users/${encodedUserId}`, {
    method: "DELETE",
  });
  clearAdminUserCaches(userId);
}
