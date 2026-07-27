"use client";

import { useQuery } from "@tanstack/react-query";
import { useMemo } from "react";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplates,
  fetchAdminTemplatesAnalyticsOverview,
  normalizeAdminTemplateCatalogQuery,
  normalizeAdminTemplatesAnalyticsQuery,
  type AdminTemplateCatalogQuery,
  type AdminTemplatesAnalyticsTemplateRow,
  type TemplateType,
} from "@/lib/api-client";

type UseAdminTemplateCatalogOptions = {
  enabled?: boolean;
  query: AdminTemplateCatalogQuery;
  templateType?: TemplateType;
};

type AnalyticsRowsMap = Record<string, AdminTemplatesAnalyticsTemplateRow>;

const EMPTY_TEMPLATE_IDS: string[] = [];

function normalizeTemplateId(templateId: string) {
  return templateId.trim().toLowerCase();
}

function createAnalyticsRowsMap(rows: AdminTemplatesAnalyticsTemplateRow[]): AnalyticsRowsMap {
  const rowsByTemplateId: AnalyticsRowsMap = {};

  for (const row of rows) {
    rowsByTemplateId[row.templateId] = row;
    rowsByTemplateId[normalizeTemplateId(row.templateId)] = row;
  }

  return rowsByTemplateId;
}

function areTemplateIdListsEqual(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

export function useAdminTemplateCatalog({
  enabled = true,
  query,
  templateType,
}: UseAdminTemplateCatalogOptions) {
  const normalizedQuery = normalizeAdminTemplateCatalogQuery(query);
  const templatesQuery = useQuery({
    queryKey: adminQueryKeys.templateCatalog(normalizedQuery),
    queryFn: ({ signal }) => fetchAdminTemplates(normalizedQuery, signal),
    enabled,
  });
  const visibleTemplateIds = useMemo(
    () => templatesQuery.data?.items.map((template) => template.templateId) ?? EMPTY_TEMPLATE_IDS,
    [templatesQuery.data?.items]
  );
  const analyticsQuery = useMemo(
    () =>
      normalizeAdminTemplatesAnalyticsQuery({
        templateType: templateType ?? "All",
        templateIds: visibleTemplateIds,
        sort: "updated",
        take: visibleTemplateIds.length,
      }),
    [templateType, visibleTemplateIds]
  );
  const analyticsTemplateIds = analyticsQuery.templateIds ?? EMPTY_TEMPLATE_IDS;

  const analyticsRowsQuery = useQuery<AnalyticsRowsMap>({
    queryKey: adminQueryKeys.templateCatalogAnalyticsRows(
      templateType ?? "all",
      analyticsTemplateIds
    ),
    queryFn: async ({ signal }) => {
      const response = await fetchAdminTemplatesAnalyticsOverview(analyticsQuery, signal);
      return createAnalyticsRowsMap(response.templates);
    },
    enabled: enabled && templatesQuery.isSuccess && analyticsTemplateIds.length > 0,
  });

  async function refresh() {
    if (!enabled) {
      return templatesQuery;
    }

    const templatesResult = await templatesQuery.refetch();

    if (templatesResult.isError) {
      throw templatesResult.error;
    }

    const refreshedTemplateIds = normalizeAdminTemplatesAnalyticsQuery({
      templateIds: templatesResult.data?.items.map((template) => template.templateId),
    }).templateIds;
    if (
      refreshedTemplateIds &&
      areTemplateIdListsEqual(refreshedTemplateIds, analyticsTemplateIds)
    ) {
      void analyticsRowsQuery.refetch().catch(() => undefined);
    }

    return templatesResult;
  }

  const analyticsRows = analyticsRowsQuery.data ?? {};

  function getAnalyticsRow(templateId: string) {
    return analyticsRows[templateId] ?? analyticsRows[normalizeTemplateId(templateId)];
  }

  return {
    analyticsRows,
    getAnalyticsRow,
    hasError: templatesQuery.isError,
    hasSecondaryError: analyticsRowsQuery.isError,
    isCatalogFetching: templatesQuery.isFetching,
    isFetching: templatesQuery.isFetching || analyticsRowsQuery.isFetching,
    isLoading: templatesQuery.isLoading,
    isSecondaryLoading: analyticsRowsQuery.isLoading,
    refresh,
    templates: templatesQuery.data?.items ?? [],
    hasMore: Boolean(templatesQuery.data?.hasMore),
    pageSkip: templatesQuery.data?.skip ?? normalizedQuery.skip ?? 0,
    pageTake: templatesQuery.data?.take ?? normalizedQuery.take ?? 24,
    summary: templatesQuery.data?.summary ?? null,
    totalCount: templatesQuery.data?.totalCount ?? 0,
  };
}
