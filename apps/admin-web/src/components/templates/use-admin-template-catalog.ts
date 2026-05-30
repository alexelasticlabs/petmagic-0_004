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
    queryFn: () => fetchAdminTemplates(templateType),
    enabled,
  });

  const analyticsRowsQuery = useQuery<AnalyticsRowsMap>({
    queryKey: adminQueryKeys.templateCatalogAnalyticsRows(templateType),
    queryFn: async () => {
      const response = await fetchAdminTemplatesAnalyticsOverview({
        templateType,
        sort: "updated",
        take: 500,
      });
      const rowsByTemplateId: AnalyticsRowsMap = {};

      for (const row of response.templates) {
        rowsByTemplateId[row.templateId] = row;
        rowsByTemplateId[normalizeTemplateId(row.templateId)] = row;
      }

      return rowsByTemplateId;
    },
    enabled,
  });

  async function refresh() {
    const [templatesResult, analyticsResult] = await Promise.all([
      templatesQuery.refetch(),
      analyticsRowsQuery.refetch(),
    ]);

    if (templatesResult.isError) {
      throw templatesResult.error;
    }

    if (analyticsResult.isError) {
      throw analyticsResult.error;
    }

    return analyticsResult;
  }

  const analyticsRows = analyticsRowsQuery.data ?? {};

  function getAnalyticsRow(templateId: string) {
    return analyticsRows[templateId] ?? analyticsRows[normalizeTemplateId(templateId)];
  }

  return {
    analyticsRows,
    getAnalyticsRow,
    hasError: templatesQuery.isError || analyticsRowsQuery.isError,
    isLoading: templatesQuery.isLoading || analyticsRowsQuery.isLoading,
    refresh,
    templates: templatesQuery.data ?? [],
  };
}
