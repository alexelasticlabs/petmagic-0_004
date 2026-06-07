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
  userId: string | null;
};

export function useAdminUserProfile({ userId }: UseAdminUserProfileOptions) {
  const userQuery = useQuery<AdminUserDetail>({
    queryKey: userId ? adminQueryKeys.userDetail(userId) : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(userId!, signal),
    enabled: Boolean(userId),
  });

  const analyticsQuery = useQuery<AdminUserAnalytics>({
    queryKey: userId ? adminQueryKeys.userAnalytics(userId) : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(userId!, signal),
    enabled: Boolean(userId),
  });

  const user = userQuery.data ?? null;
  const analytics = analyticsQuery.data ?? null;
  const isLoading =
    Boolean(userId) && (!user || !analytics) && (userQuery.isLoading || analyticsQuery.isLoading);
  const hasError =
    Boolean(userId) && ((!user && userQuery.isError) || (!analytics && analyticsQuery.isError));

  async function refresh() {
    if (!userId) {
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
