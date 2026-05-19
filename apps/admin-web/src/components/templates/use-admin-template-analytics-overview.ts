"use client";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    fetchAdminTemplate,
    fetchAdminTemplateEventAnalytics,
    fetchAdminTemplateFailureBreakdown,
    fetchAdminTemplateRecentGenerations,
    fetchAdminTemplateStatistics,
    fetchAdminTemplateTrends,
    type AdminTemplate,
    type AdminTemplateEventAnalytics,
    type AdminTemplateFailureBreakdownItem,
    type AdminTemplateRecentGeneration,
    type AdminTemplateStatistics,
    type AdminTemplateTrendPoint,
} from "@/lib/api-client";
import { useQuery } from "@tanstack/react-query";

type AdminTemplateAnalyticsOverview = {
  eventAnalytics: AdminTemplateEventAnalytics;
  failureBreakdown: AdminTemplateFailureBreakdownItem[];
  recentRunsPreview: AdminTemplateRecentGeneration[];
  statistics: AdminTemplateStatistics;
  template: AdminTemplate;
  trendPoints: AdminTemplateTrendPoint[];
};

type UseAdminTemplateAnalyticsOverviewOptions = {
  enabled?: boolean;
  previewTake?: number;
  templateId: string;
};

export function useAdminTemplateAnalyticsOverview({ enabled = true, previewTake, templateId }: UseAdminTemplateAnalyticsOverviewOptions) {
  const overviewQuery = useQuery<AdminTemplateAnalyticsOverview>({
    queryKey: adminQueryKeys.templateAnalyticsOverview(templateId),
    queryFn: async () => {
      const [template, statistics, trendPoints, recentRunsPreview, failureBreakdown, eventAnalytics] = await Promise.all([
        fetchAdminTemplate(templateId),
        fetchAdminTemplateStatistics(templateId),
        fetchAdminTemplateTrends(templateId),
        fetchAdminTemplateRecentGenerations(templateId, previewTake),
        fetchAdminTemplateFailureBreakdown(templateId),
        fetchAdminTemplateEventAnalytics(templateId),
      ]);

      return {
        eventAnalytics,
        failureBreakdown,
        recentRunsPreview,
        statistics,
        template,
        trendPoints,
      };
    },
    enabled,
  });

  return {
    eventAnalytics: overviewQuery.data?.eventAnalytics ?? null,
    failureBreakdown: overviewQuery.data?.failureBreakdown ?? [],
    hasError: overviewQuery.isError,
    isLoading: overviewQuery.isLoading,
    recentRunsPreview: overviewQuery.data?.recentRunsPreview ?? [],
    refresh: overviewQuery.refetch,
    statistics: overviewQuery.data?.statistics ?? null,
    template: overviewQuery.data?.template ?? null,
    trendPoints: overviewQuery.data?.trendPoints ?? [],
  };
}
