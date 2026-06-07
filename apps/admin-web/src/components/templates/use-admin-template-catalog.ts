"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplates,
  fetchAdminTemplatesAnalyticsOverview,
  type AdminTemplateListItem,
  type AdminTemplatesAnalyticsTemplateRow,
  type TemplateType,
} from "@/lib/api-client";

type UseAdminTemplateCatalogOptions = {
  enabled?: boolean;
  templateType: TemplateType;
};

type AnalyticsRowsMap = Record<string, AdminTemplatesAnalyticsTemplateRow>;

function normalizeTemplateId(templateId: string) {
  return templateId.trim().toLowerCase();
}

export function useAdminTemplateCatalog({
  enabled = true,
  templateType,
}: UseAdminTemplateCatalogOptions) {
  const templatesQuery = useQuery<AdminTemplateListItem[]>({
    queryKey: adminQueryKeys.templateCatalog(templateType),
    queryFn: ({ signal }) => fetchAdminTemplates(templateType, signal),
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
    enabled: enabled && templatesQuery.isSuccess && (templatesQuery.data?.length ?? 0) > 0,
  });

  async function refresh() {
    const templatesResult = await templatesQuery.refetch();

    if (templatesResult.isError) {
      throw templatesResult.error;
    }

    if ((templatesResult.data?.length ?? 0) > 0) {
      await analyticsRowsQuery.refetch();
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
    templates: templatesQuery.data ?? [],
  };
}
