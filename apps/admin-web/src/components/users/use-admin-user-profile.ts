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

  async function refresh() {
    if (!canLoadUser) {
      return;
    }

    const [userResult, analyticsResult] = await Promise.all([
      userQuery.refetch(),
      analyticsQuery.refetch(),
    ]);

    if (userResult.isError) {
      throw userResult.error;
    }

    if (analyticsResult.isError) {
      throw analyticsResult.error;
    }
  }

  return {
    analytics,
    hasError,
    isFetching: userQuery.isFetching || analyticsQuery.isFetching,
    isLoading,
    refresh,
    user,
  };
}
