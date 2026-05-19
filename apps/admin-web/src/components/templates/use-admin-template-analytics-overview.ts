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
  const primaryQuery = useQuery<Pick<AdminTemplateAnalyticsOverview, "statistics" | "template">>({
    queryKey: adminQueryKeys.templateAnalyticsPrimary(templateId),
    queryFn: async () => {
      const [template, statistics] = await Promise.all([
        fetchAdminTemplate(templateId),
        fetchAdminTemplateStatistics(templateId),
      ]);

      return {
        statistics,
        template,
      };
    },
    enabled,
  });

  const secondaryQuery = useQuery<Pick<AdminTemplateAnalyticsOverview, "eventAnalytics" | "failureBreakdown" | "recentRunsPreview" | "trendPoints">>({
    queryKey: adminQueryKeys.templateAnalyticsSecondary(templateId, previewTake),
    queryFn: async () => {
      const [trendPoints, recentRunsPreview, failureBreakdown, eventAnalytics] = await Promise.all([
        fetchAdminTemplateTrends(templateId),
        fetchAdminTemplateRecentGenerations(templateId, previewTake),
        fetchAdminTemplateFailureBreakdown(templateId),
        fetchAdminTemplateEventAnalytics(templateId),
      ]);

      return {
        eventAnalytics,
        failureBreakdown,
        recentRunsPreview,
        trendPoints,
      };
    },
    enabled: enabled && primaryQuery.isSuccess,
  });

  return {
    eventAnalytics: secondaryQuery.data?.eventAnalytics ?? null,
    failureBreakdown: secondaryQuery.data?.failureBreakdown ?? [],
    hasError: primaryQuery.isError,
    hasSecondaryError: secondaryQuery.isError,
    isLoading: primaryQuery.isLoading,
    isSecondaryLoading: primaryQuery.isSuccess && secondaryQuery.isLoading,
    recentRunsPreview: secondaryQuery.data?.recentRunsPreview ?? [],
    refresh: async () => {
      await Promise.all([primaryQuery.refetch(), secondaryQuery.refetch()]);
    },
    statistics: primaryQuery.data?.statistics ?? null,
    template: primaryQuery.data?.template ?? null,
    trendPoints: secondaryQuery.data?.trendPoints ?? [],
  };
}
