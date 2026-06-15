"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplates,
  fetchAdminTemplatesAnalyticsOverview,
  normalizeAdminTemplateCatalogQuery,
  type AdminTemplateCatalogQuery,
  type AdminTemplatesAnalyticsTemplateRow,
  type TemplateType,
} from "@/lib/api-client";

type UseAdminTemplateCatalogOptions = {
  enabled?: boolean;
  query: AdminTemplateCatalogQuery;
  templateType: TemplateType;
};

type AnalyticsRowsMap = Record<string, AdminTemplatesAnalyticsTemplateRow>;

function normalizeTemplateId(templateId: string) {
  return templateId.trim().toLowerCase();
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

  const analyticsRowsQuery = useQuery<AnalyticsRowsMap>({
    queryKey: adminQueryKeys.templateCatalogAnalyticsRows(templateType),
    queryFn: async ({ signal }) => {
      const response = await fetchAdminTemplatesAnalyticsOverview(
        {
          templateType,
          sort: "updated",
          take: 500,
        },
        signal
      );
      const rowsByTemplateId: AnalyticsRowsMap = {};

      for (const row of response.templates) {
        rowsByTemplateId[row.templateId] = row;
        rowsByTemplateId[normalizeTemplateId(row.templateId)] = row;
      }

      return rowsByTemplateId;
    },
    enabled: enabled && templatesQuery.isSuccess && (templatesQuery.data?.items.length ?? 0) > 0,
  });

  async function refresh() {
    if (!enabled) {
      return templatesQuery;
    }

    const templatesResult = await templatesQuery.refetch();

    if (templatesResult.isError) {
      throw templatesResult.error;
    }

    if ((templatesResult.data?.items.length ?? 0) > 0) {
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
    isFetching: templatesQuery.isFetching || analyticsRowsQuery.isFetching,
    isLoading: templatesQuery.isLoading,
    isSecondaryLoading: analyticsRowsQuery.isLoading,
    refresh,
    templates: templatesQuery.data?.items ?? [],
    hasMore: Boolean(templatesQuery.data?.hasMore),
    pageSkip: templatesQuery.data?.skip ?? normalizedQuery.skip ?? 0,
    pageTake: templatesQuery.data?.take ?? normalizedQuery.take ?? 24,
    totalCount: templatesQuery.data?.totalCount ?? 0,
  };
}
