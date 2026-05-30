import {
    apiRequest,
    cachedAdminUserAnalytics,
    cachedAdminUserDetails,
    cachedGet,
    cachedUsersLists,
} from "./api-client.core";

import type {
    AdminUserAnalytics,
    AdminUserDetail,
    AdminUserWalletOperation,
    UserListItem,
} from "./api-client.types";

export async function fetchUsers(): Promise<UserListItem[]> {
  return cachedGet("users", cachedUsersLists, () =>
    apiRequest<UserListItem[]>("/api/admin/users/", { method: "GET" })
  );
}

export async function fetchAdminUser(userId: string): Promise<AdminUserDetail> {
  return cachedGet(`admin-user:${userId}`, cachedAdminUserDetails, () =>
    apiRequest<AdminUserDetail>(`/api/admin/users/${userId}`, { method: "GET" })
  );
}

export async function fetchAdminUserAnalytics(userId: string): Promise<AdminUserAnalytics> {
  return cachedGet(`admin-user-analytics:${userId}`, cachedAdminUserAnalytics, () =>
    apiRequest<AdminUserAnalytics>(`/api/admin/users/${userId}/analytics`, { method: "GET" })
  );
}

export async function adjustAdminUserWallet(
  userId: string,
  operation: "credit" | "debit",
  amount: number,
  reason: string
): Promise<AdminUserWalletOperation> {
  const result = await apiRequest<AdminUserWalletOperation>(`/api/admin/users/${userId}/wallet`, {
    method: "POST",
    body: JSON.stringify({ operation, amount, reason }),
  });

  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
  return result;
}

export async function assignRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "PUT",
    body: JSON.stringify({ role }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function revokeRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "DELETE",
    body: JSON.stringify({ role }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setPremium(userId: string, isPremium: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/premium`, {
    method: "PUT",
    body: JSON.stringify({ isPremium }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function revokePremium(userId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/economy/users/${userId}/premium/revoke`, {
    method: "PUT",
    body: JSON.stringify({ paymentProvider: "stripe" }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setActive(userId: string, isActive: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/active`, {
    method: "PUT",
    body: JSON.stringify({ isActive }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function deleteAdminUser(userId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}`, {
    method: "DELETE",
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}
