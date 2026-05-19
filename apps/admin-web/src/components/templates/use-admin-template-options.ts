"use client";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminTemplates, type AdminTemplateListItem, type TemplateType } from "@/lib/api-client";
import { useQuery } from "@tanstack/react-query";

type UseAdminTemplateOptions = {
  enabled?: boolean;
  templateType: TemplateType;
};

export function useAdminTemplateOptions({ enabled = true, templateType }: UseAdminTemplateOptions) {
  const templatesQuery = useQuery<AdminTemplateListItem[]>({
    queryKey: adminQueryKeys.templateCatalog(templateType),
    queryFn: () => fetchAdminTemplates(templateType),
    enabled,
  });

  async function refresh() {
    const result = await templatesQuery.refetch();

    if (result.isError) {
      throw result.error;
    }

    return result;
  }

  return {
    hasError: templatesQuery.isError,
    isLoading: templatesQuery.isLoading || templatesQuery.isFetching,
    refresh,
    templates: templatesQuery.data ?? [],
  };
}
