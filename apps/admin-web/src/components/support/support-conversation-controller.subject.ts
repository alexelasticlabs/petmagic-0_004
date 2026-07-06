import { useQuery } from "@tanstack/react-query";

import {
  supportSubjectContextStaleTimeMs,
  isNotFoundError,
} from "@/components/support/support-conversation-controller.helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminEconomyPurchases,
  fetchAdminEconomyUserSubscriptionSummary,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  type AdminEconomyPurchase,
  type AdminEconomyUserSubscriptionSummary,
  type AdminUserAnalytics,
  type AdminUserDetail,
} from "@/lib/api-client";

type UseSupportConversationSubjectQueriesParams = {
  hasSession: boolean;
  subjectUserId: string | null;
  canViewSubjectUserContext: boolean;
};

export function useSupportConversationSubjectQueries({
  hasSession,
  subjectUserId,
  canViewSubjectUserContext,
}: UseSupportConversationSubjectQueriesParams) {
  const userQuery = useQuery<AdminUserDetail>({
    queryKey: subjectUserId
      ? adminQueryKeys.userDetail(subjectUserId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(subjectUserId!, signal),
    enabled: Boolean(hasSession && subjectUserId && canViewSubjectUserContext),
    staleTime: supportSubjectContextStaleTimeMs,
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const isSubjectUserDeleted = Boolean(
    subjectUserId && userQuery.isError && isNotFoundError(userQuery.error)
  );

  const analyticsQuery = useQuery<AdminUserAnalytics>({
    queryKey: subjectUserId
      ? adminQueryKeys.userAnalytics(subjectUserId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(subjectUserId!, signal),
    enabled: Boolean(
      hasSession && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    staleTime: supportSubjectContextStaleTimeMs,
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const purchasesQuery = useQuery<AdminEconomyPurchase[]>({
    queryKey: ["admin", "support", "conversation", subjectUserId ?? "none", "purchases"],
    queryFn: async ({ signal }) => {
      const response = await fetchAdminEconomyPurchases(
        {
          skip: 0,
          take: 8,
          userId: subjectUserId!,
        },
        signal
      );

      return response.items;
    },
    enabled: Boolean(
      hasSession && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    staleTime: supportSubjectContextStaleTimeMs,
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  const subscriptionQuery = useQuery<AdminEconomyUserSubscriptionSummary>({
    queryKey: subjectUserId
      ? adminQueryKeys.economyUserSubscriptionSummary(subjectUserId)
      : adminQueryKeys.economyUserSubscriptionSummaryDisabled,
    queryFn: ({ signal }) => fetchAdminEconomyUserSubscriptionSummary(subjectUserId!, signal),
    enabled: Boolean(
      hasSession && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted
    ),
    staleTime: supportSubjectContextStaleTimeMs,
    retry: (failureCount, error) => !isNotFoundError(error) && failureCount < 2,
  });

  return {
    analyticsQuery,
    isSubjectUserDeleted,
    purchasesQuery,
    subscriptionQuery,
    userQuery,
  };
}
