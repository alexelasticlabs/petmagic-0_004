"use client";

import { useQuery } from "@tanstack/react-query";

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

type AdminTemplateAnalyticsOverview = {
  eventAnalytics: AdminTemplateEventAnalytics;
  failureBreakdown: AdminTemplateFailureBreakdownItem[];
  hasPartialSecondaryFailure: boolean;
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

const EMPTY_EVENT_ANALYTICS: AdminTemplateEventAnalytics = {
  totalViews: 0,
  totalVideoViews: 0,
  totalComplaints: 0,
  sources: [],
  devices: [],
  geography: [],
};

function readSettledValue<T>(result: PromiseSettledResult<T>, fallback: T): T {
  return result.status === "fulfilled" ? result.value : fallback;
}

function hasRejectedResult(results: ReadonlyArray<PromiseSettledResult<unknown>>): boolean {
  return results.some((result) => result.status === "rejected");
}

export function useAdminTemplateAnalyticsOverview({
  enabled = true,
  previewTake,
  templateId,
}: UseAdminTemplateAnalyticsOverviewOptions) {
  const primaryQuery = useQuery<Pick<AdminTemplateAnalyticsOverview, "statistics" | "template">>({
    queryKey: adminQueryKeys.templateAnalyticsPrimary(templateId),
    queryFn: async ({ signal }) => {
      const [template, statistics] = await Promise.all([
        fetchAdminTemplate(templateId, signal),
        fetchAdminTemplateStatistics(templateId, signal),
      ]);

      return {
        statistics,
        template,
      };
    },
    enabled,
  });

  const secondaryQuery = useQuery<
    Pick<
      AdminTemplateAnalyticsOverview,
      | "eventAnalytics"
      | "failureBreakdown"
      | "hasPartialSecondaryFailure"
      | "recentRunsPreview"
      | "trendPoints"
    >
  >({
    queryKey: adminQueryKeys.templateAnalyticsSecondary(templateId, previewTake),
    queryFn: async ({ signal }) => {
      const results = await Promise.allSettled([
        fetchAdminTemplateTrends(templateId, signal),
        fetchAdminTemplateRecentGenerations(templateId, previewTake, signal),
        fetchAdminTemplateFailureBreakdown(templateId, signal),
        fetchAdminTemplateEventAnalytics(templateId, signal),
      ]);
      if (signal.aborted) {
        throw new DOMException("Template analytics request was aborted.", "AbortError");
      }

      const [trendPoints, recentRunsPreview, failureBreakdown, eventAnalytics] = results;

      return {
        eventAnalytics: readSettledValue(eventAnalytics, EMPTY_EVENT_ANALYTICS),
        failureBreakdown: readSettledValue(failureBreakdown, []),
        hasPartialSecondaryFailure: hasRejectedResult(results),
        recentRunsPreview: readSettledValue(recentRunsPreview, []),
        trendPoints: readSettledValue(trendPoints, []),
      };
    },
    enabled: enabled && primaryQuery.isSuccess,
  });

  return {
    eventAnalytics: secondaryQuery.data?.eventAnalytics ?? null,
    failureBreakdown: secondaryQuery.data?.failureBreakdown ?? [],
    hasError: primaryQuery.isError,
    hasSecondaryError: secondaryQuery.isError,
    hasSecondaryPartialError: secondaryQuery.data?.hasPartialSecondaryFailure ?? false,
    isFetching: primaryQuery.isFetching || secondaryQuery.isFetching,
    isLoading: primaryQuery.isLoading,
    isSecondaryLoading: primaryQuery.isSuccess && secondaryQuery.isLoading,
    recentRunsPreview: secondaryQuery.data?.recentRunsPreview ?? [],
    refresh: async () => {
      if (!enabled) {
        return;
      }

      const primaryResult = await primaryQuery.refetch();
      if (primaryResult.isError) {
        return;
      }

      await secondaryQuery.refetch();
    },
    statistics: primaryQuery.data?.statistics ?? null,
    template: primaryQuery.data?.template ?? null,
    trendPoints: secondaryQuery.data?.trendPoints ?? [],
  };
}
