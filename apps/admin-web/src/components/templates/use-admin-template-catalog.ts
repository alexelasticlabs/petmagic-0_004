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
      return Object.fromEntries(response.templates.map((row) => [row.templateId, row]));
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

    return analyticsResult;
  }

  return {
    analyticsRows: analyticsRowsQuery.data ?? {},
    hasError: templatesQuery.isError,
    isLoading: templatesQuery.isLoading,
    refresh,
    templates: templatesQuery.data ?? [],
  };
}
