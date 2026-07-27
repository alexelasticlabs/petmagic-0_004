import { apiRequest, encodePathSegment } from "./api-client.core";

import type {
  AdminGamificationAchievementDefinition,
  AdminGamificationChallengeSummary,
  AdminGamificationDashboardMetrics,
  AdminUserGamificationOverview,
} from "./api-client.types";

export async function fetchAdminGamificationDashboardMetrics(
  signal?: AbortSignal
): Promise<AdminGamificationDashboardMetrics> {
  return apiRequest<AdminGamificationDashboardMetrics>(
    "/api/admin/gamification/dashboard/metrics",
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchAdminGamificationAchievements(
  signal?: AbortSignal
): Promise<AdminGamificationAchievementDefinition[]> {
  return apiRequest<AdminGamificationAchievementDefinition[]>(
    "/api/admin/gamification/achievements",
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchAdminGamificationChallenges(
  signal?: AbortSignal
): Promise<AdminGamificationChallengeSummary[]> {
  return apiRequest<AdminGamificationChallengeSummary[]>(
    "/api/admin/gamification/challenges/current",
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchAdminUserGamificationOverview(
  userId: string,
  signal?: AbortSignal
): Promise<AdminUserGamificationOverview> {
  const encodedUserId = encodePathSegment(userId);
  return apiRequest<AdminUserGamificationOverview>(
    `/api/admin/gamification/users/${encodedUserId}`,
    {
      method: "GET",
      signal,
    }
  );
}

export async function resetAdminUserGamificationStreak(
  userId: string,
  reason: string
): Promise<void> {
  const encodedUserId = encodePathSegment(userId);
  await apiRequest<void>(`/api/admin/gamification/users/${encodedUserId}/streak/reset`, {
    method: "POST",
    body: JSON.stringify({ reason: reason.trim() }),
  });
}
