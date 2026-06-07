"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplates,
  type TemplateType,
} from "@/lib/api-client";

type UseAdminTemplateOptions = {
  enabled?: boolean;
  templateType: TemplateType;
};

export function useAdminTemplateOptions({ enabled = true, templateType }: UseAdminTemplateOptions) {
  const query = { type: templateType, status: "not_archived" as const, take: 100 };
  const templatesQuery = useQuery({
    queryKey: adminQueryKeys.templateCatalog(query),
    queryFn: ({ signal }) => fetchAdminTemplates(query, signal),
    enabled,
  });

  async function refresh() {
    if (!enabled) {
      return templatesQuery;
    }

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
    templates: templatesQuery.data?.items ?? [],
  };
}
