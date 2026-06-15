"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminUser,
  fetchAdminUserAnalytics,
  type AdminUserAnalytics,
  type AdminUserDetail,
} from "@/lib/api-client";

type UseAdminUserProfileOptions = {
  enabled?: boolean;
  userId: string | null;
};

export function useAdminUserProfile({ enabled = true, userId }: UseAdminUserProfileOptions) {
  const canLoadUser = enabled && Boolean(userId);
  const userQuery = useQuery<AdminUserDetail>({
    queryKey: userId ? adminQueryKeys.userDetail(userId) : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(userId!, signal),
    enabled: canLoadUser,
  });

  const analyticsQuery = useQuery<AdminUserAnalytics>({
    queryKey: userId ? adminQueryKeys.userAnalytics(userId) : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(userId!, signal),
    enabled: canLoadUser,
  });

  const user = userQuery.data ?? null;
  const analytics = analyticsQuery.data ?? null;
  const isLoading =
    canLoadUser && (!user || !analytics) && (userQuery.isLoading || analyticsQuery.isLoading);
  const hasError =
    canLoadUser && ((!user && userQuery.isError) || (!analytics && analyticsQuery.isError));
  const error = userQuery.error ?? analyticsQuery.error ?? null;

  async function refresh() {
    if (!canLoadUser) {
      return;
    }

    const [userResult, analyticsResult] = await Promise.allSettled([
      userQuery.refetch(),
      analyticsQuery.refetch(),
    ]);

    if (userResult.status === "rejected") {
      throw userResult.reason;
    }

    if (analyticsResult.status === "rejected") {
      throw analyticsResult.reason;
    }

    if (userResult.value.isError) {
      throw userResult.value.error;
    }

    if (analyticsResult.value.isError) {
      throw analyticsResult.value.error;
    }
  }

  return {
    analytics,
    error,
    hasError,
    isFetching: userQuery.isFetching || analyticsQuery.isFetching,
    isLoading,
    refresh,
    user,
  };
}
