"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminTemplateCategories, type AdminTemplateCategory } from "@/lib/api-client";

type UseAdminTemplateCategoriesOptions = {
  enabled?: boolean;
  includeArchived?: boolean;
};

export function useAdminTemplateCategories({
  enabled = true,
  includeArchived = true,
}: UseAdminTemplateCategoriesOptions = {}) {
  const categoriesQuery = useQuery<AdminTemplateCategory[]>({
    queryKey: adminQueryKeys.templateCategories(includeArchived),
    queryFn: ({ signal }) => fetchAdminTemplateCategories(includeArchived, signal),
    enabled,
  });

  return {
    categories: categoriesQuery.data ?? [],
    hasError: categoriesQuery.isError,
    isFetching: categoriesQuery.isFetching,
    isLoading: categoriesQuery.isLoading || categoriesQuery.isFetching,
    refresh: categoriesQuery.refetch,
  };
}
